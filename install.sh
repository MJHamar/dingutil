#!/bin/bash
set -e

# Installation script for the 'ding' utility

show_help() {
    echo "Install the 'ding' utility"
    echo ""
    echo "Usage: ./install.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help              Display this help message and exit"
    echo "  --local             Install to local user directories instead of system directories"
    echo "                      (Use this if you don't have sudo/root permissions)"
    echo ""
    echo "Examples:"
    echo "  sudo ./install.sh            # Install system-wide (requires sudo/root)"
    echo "  ./install.sh --local         # Install for current user only"
}

# Parse command-line arguments
LOCAL_INSTALL=false
for arg in "$@"; do
    case $arg in
        --help)
            show_help
            exit 0
            ;;
        --local)
            LOCAL_INSTALL=true
            ;;
        *)
            echo "Unknown option: $arg"
            show_help
            exit 1
            ;;
    esac
done

echo "Installing ding utility..."

# Determine installation directories based on installation type
if [ "$LOCAL_INSTALL" = true ]; then
    # Local installation (for users without sudo rights)
    # Check if ~/.local/bin exists and is in PATH, otherwise use ~/bin
    if [ -d "$HOME/.local/bin" ] && [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
        BIN_DIR="$HOME/.local/bin"
    elif [ -d "$HOME/bin" ] && [[ ":$PATH:" == *":$HOME/bin:"* ]]; then
        BIN_DIR="$HOME/bin"
    else
        # Create ~/.local/bin if it doesn't exist
        BIN_DIR="$HOME/.local/bin"
        mkdir -p "$BIN_DIR"
        echo "Warning: $BIN_DIR is not in your PATH."
        echo "You may need to add it to your PATH by adding this line to your .bashrc or .profile:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
    SOUND_DIR="$HOME/.local/share/dingutil/sounds"
else
    # System-wide installation
    BIN_DIR="/usr/local/bin"
    SOUND_DIR="/usr/local/share/dingutil/sounds"
    
    # Check if script is run with appropriate permissions for system installation
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: System-wide installation requires root privileges."
        echo "Please run with sudo: sudo ./install.sh"
        echo "Or use local installation: ./install.sh --local"
        exit 1
    fi
fi

echo "Creating installation directories..."
mkdir -p "$SOUND_DIR"

# Copy sound files
echo "Installing sound files to $SOUND_DIR..."
cp -f sounds/*.aiff sounds/*.wav "$SOUND_DIR/"

# Create temporary file for the script with updated paths
TEMP_SCRIPT=$(mktemp)
cat ding | sed "s|SUCCESS_SOUND=sounds/|SUCCESS_SOUND=$SOUND_DIR/|g" | \
           sed "s|ERROR_SOUND=sounds/|ERROR_SOUND=$SOUND_DIR/|g" > "$TEMP_SCRIPT"

# Install the modified script
echo "Installing ding script to $BIN_DIR/ding..."
mkdir -p "$BIN_DIR"
cp -f "$TEMP_SCRIPT" "$BIN_DIR/ding"
rm -f "$TEMP_SCRIPT"

# Set correct permissions
echo "Setting permissions..."
chmod 755 "$BIN_DIR/ding"
chmod 644 "$SOUND_DIR"/*

echo "Installation complete!"
echo "You can now use the 'ding' command from anywhere."
echo "Usage example: ding [your command]"
