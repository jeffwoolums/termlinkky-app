import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/session_manager.dart';
import '../services/connection_manager.dart';
import '../models/ai_session.dart';

class AISessionsScreen extends StatefulWidget {
  const AISessionsScreen({super.key});

  @override
  State<AISessionsScreen> createState() => _AISessionsScreenState();
}

class _AISessionsScreenState extends State<AISessionsScreen> {
  SessionManager? _sessionManager;
  final _promptController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sessionManager == null) {
      final connectionManager = context.read<ConnectionManager>();
      _sessionManager = SessionManager(connectionManager);
      if (connectionManager.isConnected) {
        _sessionManager!.refreshSessions();
      }
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionManager = context.watch<ConnectionManager>();

    return ListenableBuilder(
      listenable: _sessionManager!,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.computer, size: 16, color: Colors.green),
                      SizedBox(width: 4),
                      Text('SERVER AI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(_sessionManager!.isAttached 
                    ? _sessionManager!.attachedSession ?? 'Session'
                    : 'Sessions'),
              ],
            ),
            leading: _sessionManager!.isAttached
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => _sessionManager!.detachSession(),
                  )
                : null,
            actions: [
              if (!_sessionManager!.isAttached)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: connectionManager.isConnected 
                      ? _sessionManager!.refreshSessions 
                      : null,
                ),
            ],
          ),
          body: !connectionManager.isConnected
              ? _buildNotConnected()
              : _sessionManager!.isAttached
                  ? _buildAttachedView(connectionManager)
                  : _buildSessionsList(),
          floatingActionButton: connectionManager.isConnected && !_sessionManager!.isAttached
              ? FloatingActionButton.extended(
                  onPressed: () => _showNewSessionDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New Session'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildNotConnected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text('Not Connected', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Connect to a device to manage AI sessions'),
        ],
      ),
    );
  }

  Widget _buildSessionsList() {
    if (_sessionManager!.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sessionManager!.sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.terminal, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text('No Active Sessions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Start a new AI session to get going'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showNewSessionDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('New Session'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _sessionManager!.refreshSessions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sessionManager!.sessions.length,
        itemBuilder: (context, index) {
          final session = _sessionManager!.sessions[index];
          return _SessionCard(
            session: session,
            onAttach: () => _sessionManager!.attachSession(session.tmuxSession),
            onKill: () => _confirmKillSession(session),
          );
        },
      ),
    );
  }

  Widget _buildAttachedView(ConnectionManager connectionManager) {
    return Column(
      children: [
        // Terminal output
        Expanded(
          child: Container(
            color: Colors.black,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: connectionManager.terminalLines.length,
              itemBuilder: (context, index) {
                final line = connectionManager.terminalLines[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    line.text,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Quick actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: Row(
            children: [
              _QuickAction(icon: Icons.stop, label: 'Ctrl+C', onTap: () => connectionManager.sendRawInput('\x03')),
              _QuickAction(icon: Icons.exit_to_app, label: 'Detach', onTap: () => _sessionManager!.detachSession()),
              _QuickAction(icon: Icons.clear_all, label: 'Clear', onTap: connectionManager.clearTerminal),
            ],
          ),
        ),

        // Input bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Colors.grey.shade800)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promptController,
                  decoration: const InputDecoration(
                    hintText: 'Send to AI session...',
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontFamily: 'JetBrainsMono'),
                  onSubmitted: (_) => _sendPrompt(),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
                onPressed: _sendPrompt,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _sendPrompt() {
    final text = _promptController.text.trim();
    if (text.isEmpty) return;
    
    HapticFeedback.mediumImpact();
    _sessionManager!.sendPrompt(text);
    _promptController.clear();
  }

  void _showNewSessionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _NewSessionSheet(
        onSelect: (template) {
          Navigator.pop(context);
          _sessionManager!.createSession(template);
        },
      ),
    );
  }

  void _confirmKillSession(AISession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kill Session?'),
        content: Text('This will terminate "${session.name}". Any unsaved work will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _sessionManager!.killSession(session.tmuxSession);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Kill'),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final AISession session;
  final VoidCallback onAttach;
  final VoidCallback onKill;

  const _SessionCard({
    required this.session,
    required this.onAttach,
    required this.onKill,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onAttach,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getIcon(), color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(session.typeLabel, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    if (session.lastOutput != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        session.lastOutput!,
                        style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: onKill,
                tooltip: 'Kill session',
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (session.type) {
      case AISessionType.claudeCode: return Icons.psychology;
      case AISessionType.codex: return Icons.auto_awesome;
      case AISessionType.aider: return Icons.build;
      case AISessionType.cursor: return Icons.edit;
      case AISessionType.unknown: return Icons.terminal;
    }
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ActionChip(
        avatar: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: onTap,      ),
    );
  }
}

class _NewSessionSheet extends StatelessWidget {
  final Function(AISessionTemplate) onSelect;

  const _NewSessionSheet({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('New AI Session', style: Theme.of(context).textTheme.titleLarge),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: AISessionTemplate.templates.length,
                itemBuilder: (context, index) {
                  final template = AISessionTemplate.templates[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(_getTemplateIcon(template.type)),
                      title: Text(template.name),
                      subtitle: Text(template.description),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => onSelect(template),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _getTemplateIcon(AISessionType type) {
    switch (type) {
      case AISessionType.claudeCode: return Icons.psychology;
      case AISessionType.codex: return Icons.auto_awesome;
      case AISessionType.aider: return Icons.build;
      case AISessionType.cursor: return Icons.edit;
      case AISessionType.unknown: return Icons.terminal;
    }
  }
}
