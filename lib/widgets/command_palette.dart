import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/settings_manager.dart';
import '../services/connection_manager.dart';
import '../models/quick_command.dart';

class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key});

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsManager>();
    final connectionManager = context.read<ConnectionManager>();
    final filtered = _searchQuery.isEmpty
        ? settings.commandsByCategory
        : _filterBySearch(settings.commandsByCategory, _searchQuery);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search commands...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: filtered.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(_getCategoryIcon(entry.key), size: 16, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(entry.key.label, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                          ],
                        ),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.5, crossAxisSpacing: 8, mainAxisSpacing: 8),
                        itemCount: entry.value.length,
                        itemBuilder: (context, index) {
                          final command = entry.value[index];
                          return _CommandButton(command: command, onTap: () => _executeCommand(context, command, connectionManager, settings));
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Map<CommandCategory, List<QuickCommand>> _filterBySearch(Map<CommandCategory, List<QuickCommand>> commands, String query) {
    final search = query.toLowerCase();
    final result = <CommandCategory, List<QuickCommand>>{};
    for (final entry in commands.entries) {
      final filtered = entry.value.where((c) => c.name.toLowerCase().contains(search) || c.command.toLowerCase().contains(search)).toList();
      if (filtered.isNotEmpty) result[entry.key] = filtered;
    }
    return result;
  }

  void _executeCommand(BuildContext context, QuickCommand command, ConnectionManager connectionManager, SettingsManager settings) {
    if (command.confirmBeforeRun) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm'),
          content: Text("Run '${command.command}'?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () { Navigator.pop(ctx); _runCommand(context, command, connectionManager, settings); }, child: const Text('Run')),
          ],
        ),
      );
    } else {
      _runCommand(context, command, connectionManager, settings);
    }
  }

  void _runCommand(BuildContext context, QuickCommand command, ConnectionManager connectionManager, SettingsManager settings) {
    if (settings.hapticFeedback) HapticFeedback.mediumImpact();
    connectionManager.sendCommand(command.command);
    Navigator.pop(context);
  }

  IconData _getCategoryIcon(CommandCategory category) {
    switch (category) {
      case CommandCategory.ai: return Icons.psychology;
      case CommandCategory.git: return Icons.account_tree;
      case CommandCategory.node: return Icons.javascript;
      case CommandCategory.python: return Icons.code;
      case CommandCategory.docker: return Icons.inventory_2;
      case CommandCategory.system: return Icons.settings;
      case CommandCategory.files: return Icons.folder;
      case CommandCategory.terminal: return Icons.terminal;
      case CommandCategory.custom: return Icons.star;
    }
  }
}

class _CommandButton extends StatelessWidget {
  final QuickCommand command;
  final VoidCallback onTap;
  const _CommandButton({required this.command, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(command.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(command.command, style: TextStyle(fontSize: 10, fontFamily: 'JetBrainsMono', color: Colors.grey[500]), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
