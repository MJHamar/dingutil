#!/bin/bash
set -e

# Installation script for the 'ding' utility

echo "Installing ding utility..."

# Check if script is run with appropriate permissions
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root or with sudo"
    echo "Please run: sudo ./install.sh"
    exit 1
fi

# Create installation directories
SOUND_DIR="/usr/local/share/dingutil/sounds"
BIN_DIR="/usr/local/bin"

echo "Creating installation directories..."
mkdir -p "$SOUND_DIR"

# Copy sound files
echo "Installing sound files..."
cp -f sounds/*.aiff sounds/*.wav "$SOUND_DIR/"

# Create temporary file for the script with updated paths
TEMP_SCRIPT=$(mktemp)
cat ding | sed "s|SUCCESS_SOUND=sounds/|SUCCESS_SOUND=$SOUND_DIR/|g" | \
           sed "s|ERROR_SOUND=sounds/|ERROR_SOUND=$SOUND_DIR/|g" > "$TEMP_SCRIPT"

# Install the modified script
echo "Installing ding script to $BIN_DIR/ding..."
cp -f "$TEMP_SCRIPT" "$BIN_DIR/ding"
rm -f "$TEMP_SCRIPT"

# Set correct permissions
echo "Setting permissions..."
chmod 755 "$BIN_DIR/ding"
chmod 644 "$SOUND_DIR"/*

echo "Installation complete!"
echo "You can now use the 'ding' command from anywhere."
echo "Usage example: ding [your command]"
