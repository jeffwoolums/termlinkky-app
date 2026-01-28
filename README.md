# TermLinky (Flutter)

Cross-platform remote terminal client for developers. One codebase → iOS, Android, macOS, Windows, Linux.

## Features

- **Secure Pairing** - Certificate pinning ensures you're connecting to YOUR workstation
- **Command Palette** - Quick access to common commands (git, npm, docker, AI agents)
- **Live Terminal** - Real-time output with ANSI color support
- **Custom Commands** - Add your own frequently-used commands
- **Cross-Platform** - Same app on all devices

## Architecture

```
┌────────────────────────────────────────────────────────┐
│                    Flutter Client                       │
│  (iOS • Android • macOS • Windows • Linux)             │
└────────────────────────┬───────────────────────────────┘
                         │ WebSocket + TLS
                         │ (Certificate Pinning)
                         ▼
┌────────────────────────────────────────────────────────┐
│                    Python Server                        │
│  (macOS • Windows • Linux)                             │
└────────────────────────────────────────────────────────┘
```

## Getting Started

### Prerequisites

- Flutter SDK 3.0+
- Dart 3.0+

### Install Flutter

```bash
# macOS
brew install --cask flutter

# Or download from https://flutter.dev
```

### Run the App

```bash
cd termlinky_flutter

# Get dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Or build for specific platform
flutter build ios
flutter build apk
flutter build macos
flutter build windows
flutter build linux
```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models/
│   ├── paired_device.dart # Device + certificate data
│   ├── quick_command.dart # Command definitions
│   └── terminal_line.dart # ANSI-parsed output
├── services/
│   ├── pairing_manager.dart    # Cert pinning + pairing
│   ├── connection_manager.dart # WebSocket connections
│   └── settings_manager.dart   # Preferences + commands
├── screens/
│   ├── home_screen.dart     # Tab navigation
│   ├── terminal_screen.dart # Terminal view
│   ├── devices_screen.dart  # Paired devices
│   └── settings_screen.dart # App settings
└── widgets/
    ├── command_palette.dart # Quick command grid
    └── pairing_sheet.dart   # Pairing flow UI
```

## Server

The companion server runs on your workstation (Mac/Windows/Linux).
See `../TermLinky/server/` for the Python server.

```bash
cd ../TermLinky/server
pip install -r requirements.txt
python server.py
```

## Command Categories

| Category | Commands |
|----------|----------|
| **AI Agents** | Claude Code, Codex, Aider |
| **Git** | status, pull, push, log, diff |
| **Node.js** | npm install/dev/build/test |
| **Python** | python3, pip, pytest |
| **Docker** | ps, compose up/down |
| **System** | df, top, htop, ps |

## Security

- Certificate fingerprint stored after initial pairing
- All connections verify cert matches (pinning)
- No external CA required
- Works over any network (local, Tailscale, etc.)

## License

MIT
