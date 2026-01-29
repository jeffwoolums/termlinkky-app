import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/connection_manager.dart';
import '../services/settings_manager.dart';
import '../models/terminal_line.dart';
import '../widgets/command_palette.dart';
import '../widgets/ai_overlay.dart';

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
          // Connection status bar
          _ConnectionStatusBar(),

          // Terminal output - isolated rebuild
          Expanded(
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
                  : Consumer2<ConnectionManager, SettingsManager>(
                      builder: (context, cm, settings, _) {
                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8),
                          itemCount: cm.terminalLines.length,
                          itemBuilder: (context, index) {
                            final line = cm.terminalLines[index];
                            return _TerminalLineWidget(
                              line: line,
                              fontSize: settings.fontSize,
                            );
                          },
                        );
                      },
                    ),
            ),
          ),

          // Quick keys bar
          if (isConnected)
            Builder(
              builder: (context) {
                final cm = context.read<ConnectionManager>();
                return Container(
                  height: 44,
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    children: [
                      _QuickKey(label: '⏎', tooltip: 'Enter', onTap: () => cm.sendSpecialKey('enter')),
                      _QuickKey(label: '⇥', tooltip: 'Tab', onTap: () => cm.sendSpecialKey('tab')),
                      _QuickKey(label: '↑', tooltip: 'Up', onTap: () => cm.sendSpecialKey('up')),
                      _QuickKey(label: '↓', tooltip: 'Down', onTap: () => cm.sendSpecialKey('down')),
                      _QuickKey(label: '←', tooltip: 'Left', onTap: () => cm.sendSpecialKey('left')),
                      _QuickKey(label: '→', tooltip: 'Right', onTap: () => cm.sendSpecialKey('right')),
                      _QuickKey(label: 'Esc', tooltip: 'Escape', onTap: () => cm.sendSpecialKey('escape')),
                      _QuickKey(label: 'Ctrl', tooltip: 'Control prefix', onTap: () => _showCtrlMenu(context, cm)),
                      _QuickKey(label: '^C', tooltip: 'Ctrl+C (Cancel)', onTap: () => cm.sendSpecialKey('ctrl+c')),
                      _QuickKey(label: '^D', tooltip: 'Ctrl+D (EOF)', onTap: () => cm.sendSpecialKey('ctrl+d')),
                      _QuickKey(label: '^Z', tooltip: 'Ctrl+Z (Suspend)', onTap: () => cm.sendSpecialKey('ctrl+z')),
                      _QuickKey(label: '^L', tooltip: 'Ctrl+L (Clear)', onTap: () => cm.sendSpecialKey('ctrl+l')),
                    ],
                  ),
                );
              },
            ),

          // Input bar
          if (isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                children: [
                  Text(
                    '\$ ',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      focusNode: _inputFocus,
                      style: const TextStyle(fontFamily: 'JetBrainsMono'),
                      decoration: const InputDecoration(
                        hintText: 'Enter command...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      onSubmitted: (_) => _sendCommand(),
                    ),
                  ),
                  IconButton(
                    onPressed: _sendCommand,
                    icon: Icon(
                      Icons.send,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: isConnected && !_showAIOverlay
          ? GestureDetector(
              onLongPress: _showCommandPalette, // Long press for command palette
              child: FloatingActionButton(
                onPressed: () => setState(() => _showAIOverlay = true),
                backgroundColor: Theme.of(context).colorScheme.primary,
                tooltip: 'AI Assistant (long press for commands)',
                child: const Icon(Icons.auto_awesome),
              ),
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
                color: segment.foreground ?? Colors.white,
                backgroundColor: segment.background,
                fontWeight: segment.bold ? FontWeight.bold : FontWeight.normal,
                fontStyle: segment.italic ? FontStyle.italic : FontStyle.normal,
                decoration: segment.underline ? TextDecoration.underline : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
