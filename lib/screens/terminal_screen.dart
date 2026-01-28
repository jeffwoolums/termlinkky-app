import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/connection_manager.dart';
import '../services/settings_manager.dart';
import '../services/pairing_manager.dart';
import '../models/terminal_line.dart';
import '../widgets/command_palette.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocus = FocusNode();

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
    final connectionManager = context.watch<ConnectionManager>();
    final settings = context.watch<SettingsManager>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('TermLinkky'),
        actions: [
          if (connectionManager.isConnected)
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: connectionManager.clearTerminal,
                  child: const ListTile(
                    leading: Icon(Icons.clear_all),
                    title: Text('Clear'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  onTap: connectionManager.disconnect,
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

          // Terminal output
          Expanded(
            child: Container(
              color: Colors.black,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: connectionManager.terminalLines.length,
                itemBuilder: (context, index) {
                  final line = connectionManager.terminalLines[index];
                  return _TerminalLineWidget(
                    line: line,
                    fontSize: settings.fontSize,
                  );
                },
              ),
            ),
          ),

          // Input bar
          if (connectionManager.isConnected)
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
                    onPressed: _inputController.text.isEmpty ? null : _sendCommand,
                    icon: Icon(
                      Icons.arrow_upward,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: connectionManager.isConnected ? _showCommandPalette : null,
        backgroundColor: connectionManager.isConnected
            ? Theme.of(context).colorScheme.primary
            : Colors.grey,
        child: const Icon(Icons.apps),
      ),
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
      case ConnectionState.connected:
        statusColor = Colors.green;
        statusText = 'Connected to ${connectionManager.currentDevice?.name ?? "device"}';
      case ConnectionState.connecting:
        statusColor = Colors.yellow;
        statusText = 'Connecting...';
      case ConnectionState.disconnected:
        statusColor = Colors.grey;
        statusText = 'Not connected';
      case ConnectionState.error:
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
