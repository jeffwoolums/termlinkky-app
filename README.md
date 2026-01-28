# TermLinkky

Remote terminal access for developers. Control your workstation from anywhere.

![Logo](assets/logo.jpg)

## Features

### 📱 Client App (iOS, Android, Mac, Windows, Linux)
- **Terminal** - Full terminal access with ANSI color support
- **AI Assist** - Natural language to commands (uses your Claude/OpenAI key)
- **AI Sessions** - Monitor/control Claude Code, Codex, Aider running on your workstation
- **Command Palette** - Quick access to common commands by category
- **Secure Pairing** - Certificate pinning after initial setup

### 💻 Server (Mac, Windows, Linux)
- **Tailscale Required** - Secure VPN, no port forwarding needed
- **Auto SSL** - Self-signed certificate generation
- **WebSocket Terminal** - Real-time bidirectional I/O
- **tmux Integration** - Manage AI coding sessions

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│                    TermLinkky Client                        │
│          (iOS • Android • macOS • Windows • Linux)         │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  Terminal   │  │  AI Assist  │  │    AI Sessions      │ │
│  │             │  │  (Mode 1)   │  │     (Mode 2)        │ │
│  │  Direct     │  │  Phone AI   │  │  Observe/control    │ │
│  │  commands   │  │  → commands │  │  server AI agents   │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└────────────────────────┬───────────────────────────────────┘
                         │ Tailscale VPN + Cert Pinning
                         ▼
┌────────────────────────────────────────────────────────────┐
│                    TermLinkky Server                        │
│              (macOS • Windows • Linux)                      │
│                                                             │
│  • WebSocket terminal server                                │
│  • tmux session management                                  │
│  • Self-signed SSL certificate                              │
└────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Install Tailscale (Both Devices)

```bash
# macOS
brew install tailscale && tailscale up

# Windows
# Download from https://tailscale.com/download

# Linux
curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up
```

### 2. Start the Server

**macOS/Linux:**
```bash
cd server
./install.sh  # or install_linux.sh
python3 server.py
```

**Windows:**
```cmd
cd server
install_windows.bat
python server_windows.py
```

You'll see:
```
==================================================
  TermLinkky Server
==================================================

  ✓ Tailscale connected

  📍 Address: 100.x.x.x:8443

  🔐 Pairing Code: 123456
==================================================
```

### 3. Build & Install the App

```bash
cd termlinkky_flutter

# iOS
flutter build ios

# Android
flutter build apk

# macOS
flutter build macos

# Windows
flutter build windows

# Linux
flutter build linux
```

### 4. Pair

1. Open TermLinkky app
2. Go to Devices → Pair New Device
3. Enter Tailscale IP and port
4. Enter 6-digit pairing code
5. Done!

## AI Modes

### Mode 1: AI Assist (AI on Phone)

Use natural language to run commands on ANY server - even ones without AI installed.

```
You: "check disk space and clean temp files"
        ↓
Phone AI generates:
  • df -h
  • rm -rf /tmp/*
        ↓
Executes on server
```

**Setup:** Settings → AI → Add your Claude or OpenAI API key

### Mode 2: AI Sessions (AI on Server)

Monitor and control AI coding agents (Claude Code, Codex, Aider) running in tmux on your workstation.

- List active AI sessions
- Attach to watch output
- Send prompts
- Create new sessions
- Kill sessions

## Command Categories

| Category | Commands |
|----------|----------|
| AI Agents | Claude Code, Codex, Aider |
| Git | status, pull, push, log, diff, stash |
| Node.js | npm install/dev/build/test |
| Python | python3, pip, pytest |
| Docker | ps, compose up/down |
| System | df, top, htop, ps |
| Files | ls, tree, find |
| Terminal | clear, exit, tmux |

## Security

| Layer | Protection |
|-------|------------|
| Network | Tailscale WireGuard encryption |
| Server Binding | Only listens on Tailscale IP |
| App Layer | Certificate pinning after pairing |
| Pairing | 6-digit code prevents unauthorized setup |

## Requirements

**Client:**
- iOS 14+ / Android 8+
- macOS 12+ / Windows 10+ / Linux

**Server:**
- Python 3.9+
- Tailscale
- OpenSSL (for cert generation)

## Project Structure

```
termlinkky_flutter/
├── lib/
│   ├── main.dart
│   ├── models/           # Data structures
│   ├── services/         # Business logic
│   ├── screens/          # UI screens
│   └── widgets/          # Reusable components
├── ios/                  # iOS project
├── android/              # Android project
├── macos/                # macOS project
├── windows/              # Windows project
└── linux/                # Linux project

TermLinkky/server/
├── server.py             # Mac/Linux server
├── server_windows.py     # Windows server
├── install.sh            # Mac installer
├── install_linux.sh      # Linux installer
├── install_windows.bat   # Windows installer
└── requirements.txt
```

## License

MIT

---

Built with Flutter 💙
