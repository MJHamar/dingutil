#!/bin/bash
set -e

# Installation script for dingutil (ding, ding-smart, dingconfig, flash-border)

show_help() {
    echo "Install the dingutil suite"
    echo ""
    echo "Installs:"
    echo "  ding           — Wrap any command with a success/error sound"
    echo "  ding-smart     — Config-driven notification hook (sound + screen flash)"
    echo "  dingconfig     — CLI to manage ding-smart configs"
    echo "  flash-border   — Flash a colored border around all screens"
    echo ""
    echo "Usage: ./install.sh --platform <mac|linux> [OPTIONS]"
    echo ""
    echo "Required:"
    echo "  --platform <mac|linux>  Target platform"
    echo "    mac    — macOS (compiles Swift binary, uses afplay)"
    echo "    linux  — Arch Linux / Wayland (installs Python script, uses aplay)"
    echo ""
    echo "Options:"
    echo "  --help              Display this help message and exit"
    echo "  --local             Install to local user directories instead of system directories"
    echo "                      (Use this if you don't have sudo/root permissions)"
    echo ""
    echo "Examples:"
    echo "  sudo ./install.sh --platform mac              # macOS system-wide"
    echo "  ./install.sh --platform mac --local            # macOS local user"
    echo "  ./install.sh --platform linux --local          # Arch Linux local user"
}

# Parse command-line arguments
LOCAL_INSTALL=false
PLATFORM=""
for arg in "$@"; do
    case $arg in
        --help)
            show_help
            exit 0
            ;;
        --local)
            LOCAL_INSTALL=true
            ;;
        --platform)
            # handled below with shift
            ;;
        mac|linux)
            PLATFORM="$arg"
            ;;
        *)
            # Check if previous arg was --platform
            if [ "${prev_arg:-}" = "--platform" ]; then
                echo "Error: Invalid platform '$arg'. Must be 'mac' or 'linux'."
                exit 1
            fi
            echo "Unknown option: $arg"
            show_help
            exit 1
            ;;
    esac
    prev_arg="$arg"
done

# Validate platform
if [ -z "$PLATFORM" ]; then
    echo "Error: --platform is required."
    echo ""
    show_help
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing dingutil suite for platform: $PLATFORM"

# Determine installation directories based on installation type
if [ "$LOCAL_INSTALL" = true ]; then
    if [ -d "$HOME/.local/bin" ] && [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
        BIN_DIR="$HOME/.local/bin"
    elif [ -d "$HOME/bin" ] && [[ ":$PATH:" == *":$HOME/bin:"* ]]; then
        BIN_DIR="$HOME/bin"
    else
        BIN_DIR="$HOME/.local/bin"
        mkdir -p "$BIN_DIR"
        echo "Warning: $BIN_DIR is not in your PATH."
        echo "You may need to add it by adding this line to your .bashrc or .zshrc:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
    SOUND_DIR="$HOME/.local/share/dingutil/sounds"
else
    BIN_DIR="/usr/local/bin"
    SOUND_DIR="/usr/local/share/dingutil/sounds"

    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: System-wide installation requires root privileges."
        echo "Please run with sudo: sudo ./install.sh --platform $PLATFORM"
        echo "Or use local installation: ./install.sh --platform $PLATFORM --local"
        exit 1
    fi
fi

echo "Creating installation directories..."
mkdir -p "$BIN_DIR"
mkdir -p "$SOUND_DIR"

# --- Sound files ---
echo "Installing sound files to $SOUND_DIR..."
cp -f "$SCRIPT_DIR"/sounds/*.wav "$SOUND_DIR/"
if ls "$SCRIPT_DIR"/sounds/*.mp3 &>/dev/null; then
    cp -f "$SCRIPT_DIR"/sounds/*.mp3 "$SOUND_DIR/"
fi
chmod 644 "$SOUND_DIR"/*

# --- ding ---
echo "Installing ding to $BIN_DIR/ding..."
TEMP_SCRIPT=$(mktemp)
sed -e "s|SUCCESS_SOUND=sounds/|SUCCESS_SOUND=$SOUND_DIR/|g" \
    -e "s|ERROR_SOUND=sounds/|ERROR_SOUND=$SOUND_DIR/|g" \
    "$SCRIPT_DIR/ding" > "$TEMP_SCRIPT"
cp -f "$TEMP_SCRIPT" "$BIN_DIR/ding"
rm -f "$TEMP_SCRIPT"
chmod 755 "$BIN_DIR/ding"

# --- flash-border (platform-specific) ---
if [ "$PLATFORM" = "mac" ]; then
    echo "Compiling flash-border (Swift/AppKit)..."
    if ! command -v swiftc &>/dev/null; then
        echo "Error: swiftc not found. Install Xcode Command Line Tools:"
        echo "  xcode-select --install"
        exit 1
    fi
    swiftc -O -o "$SCRIPT_DIR/flash-border" "$SCRIPT_DIR/flash-border.swift" -framework AppKit
    cp -f "$SCRIPT_DIR/flash-border" "$BIN_DIR/flash-border"
    chmod 755 "$BIN_DIR/flash-border"
elif [ "$PLATFORM" = "linux" ]; then
    echo "Installing flash-border (Python/gtk4-layer-shell)..."
    # Check dependencies
    MISSING_DEPS=()
    python3 -c "import gi" 2>/dev/null || MISSING_DEPS+=("python-gobject")
    ldconfig -p 2>/dev/null | grep -q libgtk4-layer-shell || {
        [ -f /usr/lib/libgtk4-layer-shell.so ] || MISSING_DEPS+=("gtk4-layer-shell")
    }
    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        echo "Error: Missing dependencies: ${MISSING_DEPS[*]}"
        echo "Install them: pacman -S ${MISSING_DEPS[*]}"
        exit 1
    fi
    cp -f "$SCRIPT_DIR/flash-border-linux.py" "$BIN_DIR/flash-border"
    chmod 755 "$BIN_DIR/flash-border"
fi
echo "Installed flash-border to $BIN_DIR/flash-border"

# --- ding-smart ---
echo "Installing ding-smart to $BIN_DIR/ding-smart..."
TEMP_SCRIPT=$(mktemp)
sed -e "s|FLASH_BIN=.*|FLASH_BIN=\"$BIN_DIR/flash-border\"|" \
    -e "s|DEFAULT_SOUND=.*|DEFAULT_SOUND=\"$SOUND_DIR/mc-villager-huh.wav\"|" \
    "$SCRIPT_DIR/ding-smart" > "$TEMP_SCRIPT"
cp -f "$TEMP_SCRIPT" "$BIN_DIR/ding-smart"
rm -f "$TEMP_SCRIPT"
chmod 755 "$BIN_DIR/ding-smart"

# --- dingconfig ---
echo "Installing dingconfig to $BIN_DIR/dingconfig..."
ln -sf "$SCRIPT_DIR/dingconfig" "$BIN_DIR/dingconfig"

# --- Global config seed ---
GLOBAL_CONFIG="$HOME/.config/dingconfig.json"
if [ ! -f "$GLOBAL_CONFIG" ]; then
    echo "Creating default global config at $GLOBAL_CONFIG..."
    mkdir -p "$(dirname "$GLOBAL_CONFIG")"
    cat > "$GLOBAL_CONFIG" <<EOF
{
  "sound": true,
  "blink": true,
  "default": {
    "soundfile": "$SOUND_DIR/mc-villager-huh.wav",
    "blink_color": "orange"
  }
}
EOF
else
    echo "Global config already exists at $GLOBAL_CONFIG — skipping."
fi

echo ""
echo "Installation complete! ($PLATFORM)"
echo ""
echo "Installed:"
echo "  ding           — $BIN_DIR/ding"
echo "  ding-smart     — $BIN_DIR/ding-smart"
echo "  dingconfig     — $BIN_DIR/dingconfig"
echo "  flash-border   — $BIN_DIR/flash-border"
echo "  sounds         — $SOUND_DIR/"
echo "  global config  — $GLOBAL_CONFIG"
echo ""
echo "Usage:"
echo "  ding <command>                    # Wrap a command with sound"
echo "  dingconfig list                   # List notification configs"
echo "  dingconfig set [path] [options]   # Configure a project"
echo "  dingconfig enable sound|blink     # Enable a global toggle"
echo "  dingconfig disable sound|blink    # Disable a global toggle"
echo "  flash-border --color red          # Flash screen border"
