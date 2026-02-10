#!/usr/bin/env python3
"""flash-border-linux — Flash a colored border around all screens on Wayland (Hyprland).

Uses gtk4-layer-shell to create a transparent overlay on the OVERLAY layer,
draws a border with Cairo, then fades it out.

Dependencies (Arch): gtk4-layer-shell python-gobject gtk4

Usage: flash-border-linux [options]

Options:
  --color, -c <name|#hex>   Border color (default: orange)
  --width, -w <pixels>      Border width in pixels (default: 6)
  --hold <seconds>          How long to show the border (default: 0.4)
  --fade <seconds>          Fade-out duration (default: 0.3)
  --help, -h                Show this help
"""

import argparse
import sys
from ctypes import CDLL

# Load the layer-shell library before importing GI bindings
try:
    CDLL("libgtk4-layer-shell.so")
except OSError:
    print("Error: libgtk4-layer-shell.so not found.", file=sys.stderr)
    print("Install it: pacman -S gtk4-layer-shell", file=sys.stderr)
    sys.exit(1)

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")

from gi.repository import Gdk, GLib, Gtk
from gi.repository import Gtk4LayerShell as LayerShell

NAMED_COLORS = {
    "red": (1.0, 0.0, 0.0),
    "orange": (1.0, 0.6, 0.0),
    "yellow": (1.0, 1.0, 0.0),
    "green": (0.0, 0.8, 0.0),
    "blue": (0.0, 0.4, 1.0),
    "purple": (0.6, 0.2, 0.8),
    "cyan": (0.0, 0.8, 0.8),
    "white": (1.0, 1.0, 1.0),
    "pink": (1.0, 0.4, 0.7),
}


def parse_color(name: str) -> tuple[float, float, float]:
    lower = name.lower().lstrip("#")
    if name.lower() in NAMED_COLORS:
        return NAMED_COLORS[name.lower()]
    # Try hex (with or without #)
    hexstr = name.lstrip("#")
    if len(hexstr) == 6:
        try:
            val = int(hexstr, 16)
            return (
                ((val >> 16) & 0xFF) / 255.0,
                ((val >> 8) & 0xFF) / 255.0,
                (val & 0xFF) / 255.0,
            )
        except ValueError:
            pass
    return NAMED_COLORS["red"]


class FlashBorderApp(Gtk.Application):
    def __init__(self, color: tuple, border_width: int, hold: float, fade: float):
        super().__init__(application_id="com.dingutil.flashborder")
        self.color = color
        self.border_width = border_width
        self.hold = hold
        self.fade = fade
        self.alpha = 1.0
        self.windows: list[Gtk.Window] = []

    def do_activate(self):
        display = Gdk.Display.get_default()
        monitors = display.get_monitors()

        for i in range(monitors.get_n_items()):
            monitor = monitors.get_item(i)
            win = self._create_overlay(monitor)
            self.windows.append(win)
            win.present()

        # Start fade after hold period
        GLib.timeout_add(int(self.hold * 1000), self._start_fade)

    def _create_overlay(self, monitor: Gdk.Monitor) -> Gtk.Window:
        win = Gtk.Window(application=self)
        win.set_decorated(False)

        # Layer shell setup
        LayerShell.init_for_window(win)
        LayerShell.set_layer(win, LayerShell.Layer.OVERLAY)
        LayerShell.set_namespace(win, "dingutil-flash")
        LayerShell.set_monitor(win, monitor)
        LayerShell.set_keyboard_mode(win, LayerShell.KeyboardMode.NONE)
        LayerShell.set_exclusive_zone(win, -1)

        # Anchor to all edges = fullscreen
        for edge in (
            LayerShell.Edge.TOP,
            LayerShell.Edge.BOTTOM,
            LayerShell.Edge.LEFT,
            LayerShell.Edge.RIGHT,
        ):
            LayerShell.set_anchor(win, edge, True)

        # Transparent background via CSS
        css = Gtk.CssProvider()
        css.load_from_string("window { background: transparent; }")
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        # Drawing area for the border
        area = Gtk.DrawingArea()
        area.set_draw_func(self._draw_border)
        area.set_hexpand(True)
        area.set_vexpand(True)
        win.set_child(area)

        return win

    def _draw_border(self, area: Gtk.DrawingArea, cr, width: int, height: int):
        r, g, b = self.color
        a = self.alpha
        bw = self.border_width

        cr.set_source_rgba(r, g, b, a)

        # Top
        cr.rectangle(0, 0, width, bw)
        cr.fill()
        # Bottom
        cr.rectangle(0, height - bw, width, bw)
        cr.fill()
        # Left
        cr.rectangle(0, bw, bw, height - 2 * bw)
        cr.fill()
        # Right
        cr.rectangle(width - bw, bw, bw, height - 2 * bw)
        cr.fill()

    def _start_fade(self) -> bool:
        if self.fade <= 0:
            self.quit()
            return False
        interval_ms = 16  # ~60fps
        steps = max(1, int(self.fade * 1000 / interval_ms))
        self.alpha_step = self.alpha / steps
        GLib.timeout_add(interval_ms, self._fade_tick)
        return False

    def _fade_tick(self) -> bool:
        self.alpha -= self.alpha_step
        if self.alpha <= 0:
            self.quit()
            return False
        for win in self.windows:
            child = win.get_child()
            if child:
                child.queue_draw()
        return True


def main():
    parser = argparse.ArgumentParser(
        description="Flash a colored border around all screens"
    )
    parser.add_argument(
        "--color", "-c", default="orange", help="Border color (name or #hex)"
    )
    parser.add_argument(
        "--width", "-w", type=int, default=6, help="Border width in pixels"
    )
    parser.add_argument(
        "--hold", type=float, default=0.4, help="How long to show the border (seconds)"
    )
    parser.add_argument(
        "--fade", type=float, default=0.3, help="Fade-out duration (seconds)"
    )
    args = parser.parse_args()

    color = parse_color(args.color)
    app = FlashBorderApp(color, args.width, args.hold, args.fade)
    app.run([])


if __name__ == "__main__":
    main()
