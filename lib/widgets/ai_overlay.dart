import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/ai_assistant.dart';
import '../services/connection_manager.dart';
import '../services/settings_manager.dart';

/// Inline AI assistant overlay that appears over the terminal.
/// Shows context, accepts natural language input, and injects commands.
class AIOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final ScrollController terminalScrollController;

  const AIOverlay({
    super.key,
    required this.onDismiss,
    required this.terminalScrollController,
  });

  @override
  State<AIOverlay> createState() => _AIOverlayState();
}

class _AIOverlayState extends State<AIOverlay> {
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final ai = context.read<AIAssistant>();
    final connection = context.read<ConnectionManager>();
    final settings = context.read<SettingsManager>();

    if (settings.hapticFeedback) HapticFeedback.lightImpact();

    ai.setContext(
      recentOutput: connection.terminalLines.map((l) => l.text).toList(),
    );

    _inputController.clear();
    await ai.sendMessage(text);
  }

  void _executeCommand(String command) {
    final connection = context.read<ConnectionManager>();
    final settings = context.read<SettingsManager>();

    if (settings.hapticFeedback) HapticFeedback.mediumImpact();
    connection.sendCommand(command);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.terminalScrollController.hasClients) {
        widget.terminalScrollController.animateTo(
          widget.terminalScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.play_arrow, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                command,
                style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  Widget _buildLastResponse(AIAssistant ai, bool canExecute) {
    // Show only the last AI response (not user messages)
    final lastAIMessage = ai.messages.reversed.firstWhere(
      (m) => m.role == 'assistant',
      orElse: () => ai.messages.last,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lastAIMessage.content,
            style: const TextStyle(fontSize: 14),
          ),
          if (lastAIMessage.suggestedCommands != null &&
              lastAIMessage.suggestedCommands!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...lastAIMessage.suggestedCommands!.map(
              (cmd) => _CommandChip(
                command: cmd,
                canExecute: canExecute,
                onExecute: () => _executeCommand(cmd),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AIAssistant>();
    final connection = context.watch<ConnectionManager>();

    final recentLines = connection.terminalLines
        .map((l) => l.text)
        .toList()
        .reversed
        .take(3)
        .toList()
        .reversed
        .join('\n');

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          widget.onDismiss();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'AI Assistant',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onDismiss,
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),

            // Context preview - what AI "sees"
            if (recentLines.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.visibility, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recentLines,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 10,
                          color: Colors.grey[400],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // API key warning
            if (!ai.isConfigured)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.key, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Add API key in Settings', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),

            // Last AI response
            if (ai.messages.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildLastResponse(ai, connection.isConnected),
                ),
              ),
            ],

            // Loading
            if (ai.isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Thinking...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),

            // Input field
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      focusNode: _inputFocus,
                      decoration: const InputDecoration(
                        hintText: 'Ask AI for help...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    onPressed: ai.isConfigured && !ai.isLoading ? _sendMessage : null,
                    icon: Icon(
                      Icons.send_rounded,
                      color: ai.isConfigured
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // Safe area padding
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

/// Individual command chip with execute button
class _CommandChip extends StatelessWidget {
  final String command;
  final bool canExecute;
  final VoidCallback onExecute;

  const _CommandChip({
    required this.command,
    required this.canExecute,
    required this.onExecute,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                command,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: canExecute ? Colors.green : Colors.grey,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: canExecute ? onExecute : null,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Run', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
