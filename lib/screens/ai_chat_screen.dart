import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/ai_assistant.dart';
import '../services/connection_manager.dart';
import '../services/settings_manager.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final ai = context.read<AIAssistant>();
    final connection = context.read<ConnectionManager>();

    ai.setContext(recentOutput: connection.terminalLines.map((l) => l.text).toList());
    _inputController.clear();
    await ai.sendMessage(text);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _executeCommand(String command) {
    final connection = context.read<ConnectionManager>();
    final settings = context.read<SettingsManager>();
    if (settings.hapticFeedback) HapticFeedback.mediumImpact();
    connection.sendCommand(command);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Executing: $command'), duration: const Duration(seconds: 1)));
  }

  void _executeAll(List<String> commands) {
    for (final cmd in commands) {
      _executeCommand(cmd);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AIAssistant>();
    final connection = context.watch<ConnectionManager>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: ai.messages.isEmpty ? null : () => ai.clearMessages()),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => _showSettings(context)),
        ],
      ),
      body: Column(
        children: [
          // Connection status
          if (!connection.isConnected)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.orange.withOpacity(0.2),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('Connect to a device first to execute commands', style: TextStyle(fontSize: 13))),
                ],
              ),
            ),

          // API key warning
          if (!ai.isConfigured)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue.withOpacity(0.2),
              child: Row(
                children: [
                  const Icon(Icons.key, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Add your API key to use AI Assistant', style: TextStyle(fontSize: 13))),
                  TextButton(onPressed: () => _showSettings(context), child: const Text('Setup')),
                ],
              ),
            ),

          // Messages
          Expanded(
            child: ai.messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: ai.messages.length + (ai.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == ai.messages.length) {
                        return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                      }
                      return _MessageBubble(
                        message: ai.messages[index],
                        onExecute: connection.isConnected ? _executeCommand : null,
                        onExecuteAll: connection.isConnected ? _executeAll : null,
                      );
                    },
                  ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, border: Border(top: BorderSide(color: Colors.grey.shade800))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: const InputDecoration(hintText: 'Ask AI to help with a task...', border: InputBorder.none),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  onPressed: ai.isConfigured && !ai.isLoading ? _sendMessage : null,
                  icon: Icon(Icons.send, color: ai.isConfigured ? Theme.of(context).colorScheme.primary : Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, size: 64, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('AI Assistant', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Describe what you want to do in plain English', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _SuggestionChip('Check disk space', onTap: () => _inputController.text = 'Check disk space'),
              _SuggestionChip('Update my git repo', onTap: () => _inputController.text = 'Pull latest changes from git'),
              _SuggestionChip('Find large files', onTap: () => _inputController.text = 'Find files larger than 100MB'),
              _SuggestionChip('Restart my server', onTap: () => _inputController.text = 'Restart the node server'),
            ],
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AISettingsSheet(),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip(this.label, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label, style: const TextStyle(fontSize: 12)), onPressed: onTap);
  }
}

class _MessageBubble extends StatelessWidget {
  final AIMessage message;
  final Function(String)? onExecute;
  final Function(List<String>)? onExecuteAll;

  const _MessageBubble({required this.message, this.onExecute, this.onExecuteAll});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isUser ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.content, style: TextStyle(color: isUser ? Colors.white : null)),
            if (message.suggestedCommands != null && message.suggestedCommands!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ...message.suggestedCommands!.map((cmd) => _CommandRow(command: cmd, onExecute: onExecute)),
              if (message.suggestedCommands!.length > 1) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onExecuteAll != null ? () => onExecuteAll!(message.suggestedCommands!) : null,
                    child: const Text('Run All'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  final String command;
  final Function(String)? onExecute;
  const _CommandRow({required this.command, this.onExecute});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(6)),
              child: Text(command, style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.play_arrow, color: onExecute != null ? Colors.green : Colors.grey),
            onPressed: onExecute != null ? () => onExecute!(command) : null,
            tooltip: 'Execute',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _AISettingsSheet extends StatefulWidget {
  const _AISettingsSheet();

  @override
  State<_AISettingsSheet> createState() => _AISettingsSheetState();
}

class _AISettingsSheetState extends State<_AISettingsSheet> {
  final _keyController = TextEditingController();
  AIProvider _selectedProvider = AIProvider.claude;

  @override
  void initState() {
    super.initState();
    final ai = context.read<AIAssistant>();
    _keyController.text = ai.apiKey ?? '';
    _selectedProvider = ai.provider;
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Text('AI Settings', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              const Text('Provider'),
              const SizedBox(height: 8),
              SegmentedButton<AIProvider>(
                segments: const [
                  ButtonSegment(value: AIProvider.claude, label: Text('Claude')),
                  ButtonSegment(value: AIProvider.openai, label: Text('OpenAI')),
                ],
                selected: {_selectedProvider},
                onSelectionChanged: (set) => setState(() => _selectedProvider = set.first),
              ),
              const SizedBox(height: 16),
              Text(_selectedProvider == AIProvider.claude ? 'Claude API Key' : 'OpenAI API Key'),
              const SizedBox(height: 8),
              TextField(
                controller: _keyController,
                decoration: InputDecoration(
                  hintText: _selectedProvider == AIProvider.claude ? 'sk-ant-...' : 'sk-...',
                  border: const OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              Text(
                _selectedProvider == AIProvider.claude 
                    ? 'Get your key at console.anthropic.com' 
                    : 'Get your key at platform.openai.com',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    context.read<AIAssistant>().setApiKey(_keyController.text, _selectedProvider);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
