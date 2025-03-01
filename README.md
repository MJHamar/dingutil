# Dingutil

A simple command-line utility that plays a sound when your command finishes executing. Get audio feedback on command success or failure without having to stare at your terminal!

## Features

- Plays a pleasant bell sound when a command completes successfully
- Plays a different sound when a command fails
- Works with any command or script
- Supports macOS and Linux
- Minimal dependencies
- Simple installation

## Installation

### Requirements

- **macOS**: No additional dependencies (uses built-in `afplay`)
- **Linux**: `paplay` (PulseAudio, comes pre-installed on most modern Linux distros)

### Installation Options

#### System-wide Installation (requires sudo/root)

```bash
sudo ./install.sh
```

#### User-local Installation (no sudo required)

```bash
./install.sh --local
```

If you install locally and the installation directory isn't in your PATH, you'll get instructions on how to add it.

#### Installation Help

```bash
./install.sh --help
```

## Usage

Simply prefix any command with `ding`:

```bash
ding ls -la
ding python my_script.py
ding make all
```

After your command finishes:
- If successful (exit code 0): You'll hear a success sound (bell)
- If failed (non-zero exit code): You'll hear an error sound

## How It Works

The `ding` script runs your command and tracks its exit code. Based on the exit code, it plays an appropriate sound to notify you of the result.

## Project Structure

- `ding`: The main script
- `sounds/`: Directory containing sound files
  - `classic-bike-bell-distorted-double-1.aiff`: Success sound
  - `bottlefullmute-1.wav`: Error sound
- `install.sh`: Installation script with options for system-wide or local installation

## License

See the [LICENSE](LICENSE) file for details.

## Contributing

Feel free to open issues or submit pull requests if you have suggestions for improvements! 