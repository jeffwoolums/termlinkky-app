# TermLinkky Flutter App

iOS/Android client for TermLinkky - remote terminal with AI assistance.

## Features

- 📱 **Remote Terminal** - Connect to your Mac over Tailscale
- 🤖 **AI Assistant** - On-device Claude/OpenAI integration
- 🔐 **Secure** - TLS + certificate pinning
- 🔄 **Auto-reconnect** - Handles network interruptions gracefully
- ⌨️ **Quick Keys** - Arrow keys, Ctrl combos, special keys
- 🎨 **ANSI Colors** - Full terminal color support

## Requirements

- Flutter 3.22+
- iOS 15+ or Android 8+
- Tailscale (on phone and server)

## Building

```bash
# Get dependencies
flutter pub get

# Run in debug mode
flutter run

# Build for iOS (needs code signing)
flutter build ios

# Build for Android
flutter build apk
```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models/
│   ├── paired_device.dart # Device pairing model
│   ├── terminal_line.dart # ANSI parser & styled segments
│   ├── quick_command.dart # Quick command model
│   └── ai_session.dart    # AI session model
├── screens/
│   ├── home_screen.dart       # Main navigation
│   ├── terminal_screen.dart   # Terminal UI
│   ├── ai_chat_screen.dart    # Local AI mode
│   ├── ai_sessions_screen.dart # Server AI mode
│   ├── devices_screen.dart    # Device management
│   ├── settings_screen.dart   # App settings
│   └── onboarding_screen.dart # First-run setup
├── services/
│   ├── connection_manager.dart # WebSocket + state
│   ├── pairing_manager.dart    # Device pairing
│   ├── settings_manager.dart   # Persistent settings
│   ├── ai_assistant.dart       # AI API integration
│   └── device_discovery.dart   # Network scanning
└── widgets/
    ├── ai_overlay.dart      # Inline AI assistant
    ├── command_palette.dart # Quick commands sheet
    └── pairing_sheet.dart   # Pairing flow UI
```

## Architecture

### State Management

Uses Provider with ChangeNotifier:

- `ConnectionManager` - WebSocket connection state
- `PairingManager` - Paired devices list
- `SettingsManager` - User preferences
- `AIAssistant` - AI state and messages

### Terminal Rendering

- ANSI escape sequences parsed in `terminal_line.dart`
- Supports: colors (16 + bright), bold, italic, underline
- Non-color escapes (cursor movement, etc.) are stripped

### Connection Security

1. TLS encryption (WSS)
2. Certificate fingerprint verification
3. 6-digit pairing code for initial trust

## Configuration

### API Keys

Set in app Settings or via environment:

```dart
// Claude
ANTHROPIC_API_KEY=sk-ant-...

// OpenAI  
OPENAI_API_KEY=sk-...
```

### Server Connection

Default port: 8443
Protocol: WSS (WebSocket Secure)

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

## Contributing

1. Fork the repo
2. Create feature branch
3. Make changes with tests
4. Submit PR

## License

Proprietary - TRED Technologies

---

**Server**: See `TermLinkky/server/` for Python server code.
**Docs**: See `TermLinkky/DOCS.md` for full documentation.
