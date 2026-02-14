import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/connection_manager.dart';
import '../services/settings_manager.dart';
import '../models/terminal_line.dart';
import '../widgets/command_palette.dart';
import '../widgets/ai_overlay.dart';
import '../widgets/real_terminal_view.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocus = FocusNode();
  bool _showAIOverlay = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _sendCommand() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final connectionManager = context.read<ConnectionManager>();
    final settings = context.read<SettingsManager>();

    if (settings.hapticFeedback) {
      HapticFeedback.mediumImpact();
    }

    connectionManager.sendCommand(text);
    _inputController.clear();

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showCommandPalette() {
    final connectionManager = context.read<ConnectionManager>();
    if (!connectionManager.isConnected) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const CommandPalette(),
    );
  }

  void _showSpecialKeysPopup(BuildContext context) {
    final cm = context.read<ConnectionManager>();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)),
            ),
            // Arrow keys - stay open for repeated presses!
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _KeyButton(label: '↑', onTap: () => cm.sendSpecialKey('up')),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _KeyButton(label: '←', onTap: () => cm.sendSpecialKey('left')),
                _KeyButton(label: '↓', onTap: () => cm.sendSpecialKey('down')),
                _KeyButton(label: '→', onTap: () => cm.sendSpecialKey('right')),
              ],
            ),
            const SizedBox(height: 8),
            // Common keys - also stay open
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _KeyButton(label: 'Enter', onTap: () => cm.sendSpecialKey('enter')),
                _KeyButton(label: 'Tab', onTap: () => cm.sendSpecialKey('tab')),
                _KeyButton(label: 'Esc', onTap: () => cm.sendSpecialKey('escape')),
                _KeyButton(label: '^C', onTap: () => cm.sendSpecialKey('ctrl+c')),
                _KeyButton(label: '^D', onTap: () => cm.sendSpecialKey('ctrl+d')),
                _KeyButton(label: '^Z', onTap: () => cm.sendSpecialKey('ctrl+z')),
                _KeyButton(label: '^L', onTap: () => cm.sendSpecialKey('ctrl+l')),
              ],
            ),
            const SizedBox(height: 12),
            // Done button to close
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only watch connection state, not terminal lines
    final isConnected = context.select<ConnectionManager, bool>((cm) => cm.isConnected);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TermLinkky'),
        actions: [
          // Commands button - always visible when connected
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.apps),
              tooltip: 'Quick Commands',
              onPressed: _showCommandPalette,
            ),
          if (isConnected)
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: () => context.read<ConnectionManager>().clearTerminal(),
                  child: const ListTile(
                    leading: Icon(Icons.clear_all),
                    title: Text('Clear'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  onTap: () => context.read<ConnectionManager>().disconnect(),
                  child: const ListTile(
                    leading: Icon(Icons.wifi_off, color: Colors.red),
                    title: Text('Disconnect'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Connection status bar - hide in landscape for more terminal space
          if (MediaQuery.of(context).orientation == Orientation.portrait)
            _ConnectionStatusBar(),

          // Terminal output - isolated rebuild with safe area for notch
          Expanded(
            child: SafeArea(
              top: false, // Status bar handled elsewhere
              bottom: false, // Nav bar handles bottom
              left: true, // Protect from notch in landscape
              right: true, // Protect from notch in landscape
              child: Container(
                color: Colors.black,
                child: !isConnected
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.terminal, size: 64, color: Colors.grey[600]),
                            const SizedBox(height: 16),
                            Text('Not Connected', style: TextStyle(color: Colors.grey[400], fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Connect to a server to use the terminal', style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 24),
                            Text('👉 Go to Devices tab to connect', style: TextStyle(color: Colors.blue[300], fontSize: 14)),
                          ],
                        ),
                      )
                    : Consumer<ConnectionManager>(
                        builder: (context, cm, _) {
                          return GestureDetector(
                            onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap
                            child: RealTerminalView(
                              outputStream: cm.outputStream,
                              onInput: (input) => cm.sendRawInput(input),
                              onResize: (cols, rows) => cm.sendResize(cols, rows),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),

          // Minimal input bar for reliable iOS keyboard
          if (isConnected)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: Colors.black,
                child: Row(
                  children: [
                    Text('> ', style: TextStyle(color: Colors.green, fontFamily: 'JetBrainsMono', fontSize: 14)),
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        focusNode: _inputFocus,
                        style: const TextStyle(color: Colors.green, fontFamily: 'JetBrainsMono', fontSize: 14),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'type here...',
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                        cursorColor: Colors.green,
                        autocorrect: false,
                        enableSuggestions: false,
                        onSubmitted: (_) => _sendCommand(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.green, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _sendCommand,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: isConnected && !_showAIOverlay
          ? FloatingActionButton(
              onPressed: () => _showSpecialKeysPopup(context),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              tooltip: 'Special Keys',
              mini: true,
              child: Icon(Icons.keyboard, color: Theme.of(context).colorScheme.onPrimaryContainer),
            )
          : null,
      bottomSheet: _showAIOverlay
          ? AIOverlay(
              onDismiss: () => setState(() => _showAIOverlay = false),
              terminalScrollController: _scrollController,
            )
          : null,
    );
  }
}

class _ConnectionStatusBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final connectionManager = context.watch<ConnectionManager>();

    Color statusColor;
    String statusText;

    switch (connectionManager.state) {
      case AppConnectionState.connected:
        statusColor = Colors.green;
        statusText = 'Connected to ${connectionManager.currentDevice?.name ?? "device"}';
      case AppConnectionState.connecting:
        statusColor = Colors.yellow;
        statusText = 'Connecting...';
      case AppConnectionState.disconnected:
        statusColor = Colors.grey;
        statusText = 'Not connected';
      case AppConnectionState.error:
        statusColor = Colors.red;
        statusText = connectionManager.errorMessage ?? 'Error';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickKey extends StatelessWidget {
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  const _QuickKey({required this.label, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showCtrlMenu(BuildContext context, ConnectionManager connectionManager) {
  showModalBottomSheet(
    context: context,
    builder: (context) => Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ctrl + Key', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').map((char) {
              return ActionChip(
                label: Text('^$char'),
                onPressed: () {
                  connectionManager.sendSpecialKey('ctrl+${char.toLowerCase()}');
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

class _TerminalLineWidget extends StatelessWidget {
  final TerminalLine line;
  final double fontSize;

  const _TerminalLineWidget({required this.line, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: RichText(
        text: TextSpan(
          children: line.segments.map((segment) {
            return TextSpan(
              text: segment.text,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: fontSize,
                // Classic terminal green - ignore ANSI colors for clean look
                color: const Color(0xFF33FF33),
                backgroundColor: null, // No background colors
                fontWeight: segment.bold ? FontWeight.bold : FontWeight.normal,
                fontStyle: FontStyle.normal, // No italics
                decoration: null, // No underlines
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// Compact quick key for landscape mode
class _MiniKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MiniKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

// Key button for special keys popup
class _KeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _KeyButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
