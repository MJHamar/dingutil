import AppKit

// MARK: - Border View

class BorderView: NSView {
    let borderWidth: CGFloat
    let borderColor: NSColor

    init(frame: NSRect, borderWidth: CGFloat, borderColor: NSColor) {
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        borderColor.setFill()
        let outer = NSBezierPath(rect: bounds)
        let inner = NSBezierPath(rect: bounds.insetBy(dx: borderWidth, dy: borderWidth))
        outer.append(inner.reversed)
        outer.fill()
    }
}

// MARK: - Border Flash Window

class BorderFlashWindow: NSWindow {
    convenience init(screen: NSScreen, borderWidth: CGFloat, borderColor: NSColor) {
        self.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.setFrame(screen.frame, display: false)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .screenSaver
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hasShadow = false

        let view = BorderView(
            frame: self.contentView!.bounds,
            borderWidth: borderWidth,
            borderColor: borderColor
        )
        view.autoresizingMask = [.width, .height]
        self.contentView?.addSubview(view)
    }
}

// MARK: - Color Parsing

func parseHex(_ hex: String) -> NSColor? {
    let clean = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    guard clean.count == 6, let val = UInt64(clean, radix: 16) else { return nil }
    return NSColor(
        red:   CGFloat((val >> 16) & 0xFF) / 255,
        green: CGFloat((val >> 8)  & 0xFF) / 255,
        blue:  CGFloat(val         & 0xFF) / 255,
        alpha: 1
    )
}

func parseColor(_ name: String) -> NSColor {
    // Try hex first (with or without #)
    if let hex = parseHex(name) { return hex }

    switch name.lowercased() {
    case "red":    return .systemRed
    case "orange": return .systemOrange
    case "yellow": return .systemYellow
    case "green":  return .systemGreen
    case "blue":   return .systemBlue
    case "purple": return .systemPurple
    case "cyan":   return .cyan
    case "white":  return .white
    case "pink":   return .systemPink
    default:       return .systemRed
    }
}

// MARK: - Main

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // no Dock icon

// Defaults
var colorName = "orange"
var borderWidth: CGFloat = 6
var holdDuration: TimeInterval = 0.4
var fadeDuration: TimeInterval = 0.3

// Parse CLI arguments
let args = CommandLine.arguments
var i = 1
while i < args.count {
    switch args[i] {
    case "--color", "-c":
        if i + 1 < args.count { colorName = args[i + 1]; i += 1 }
    case "--width", "-w":
        if i + 1 < args.count { borderWidth = CGFloat(Double(args[i + 1]) ?? 6); i += 1 }
    case "--hold":
        if i + 1 < args.count { holdDuration = Double(args[i + 1]) ?? 0.4; i += 1 }
    case "--fade":
        if i + 1 < args.count { fadeDuration = Double(args[i + 1]) ?? 0.3; i += 1 }
    case "--help", "-h":
        print("""
        flash-border - Flash a colored border around all screens

        Usage: flash-border [options]

        Options:
          --color, -c <name|#hex>   Border color (default: orange)
                                    Names: red, orange, yellow, green, blue, purple, cyan, white, pink
                                    Hex: #FF6600
          --width, -w <pixels>      Border width in pixels (default: 6)
          --hold <seconds>          How long to show the border (default: 0.4)
          --fade <seconds>          Fade-out duration (default: 0.3)
          --help, -h                Show this help
        """)
        exit(0)
    default:
        break
    }
    i += 1
}

let color = parseColor(colorName)

// Create flash windows on all screens
var windows: [BorderFlashWindow] = []
for screen in NSScreen.screens {
    let window = BorderFlashWindow(screen: screen, borderWidth: borderWidth, borderColor: color)
    window.orderFrontRegardless()
    windows.append(window)
}

// Hold, then fade out, then exit
DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) {
    NSAnimationContext.runAnimationGroup({ context in
        context.duration = fadeDuration
        for window in windows {
            window.animator().alphaValue = 0
        }
    }, completionHandler: {
        app.terminate(nil)
    })
}

app.run()
