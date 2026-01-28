import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_manager.dart';
import '../models/quick_command.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsManager>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Terminal section
          const _SectionHeader('TERMINAL'),
          ListTile(
            title: const Text('Font Size'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${settings.fontSize.toInt()}'),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: settings.fontSize > 10
                      ? () => settings.setFontSize(settings.fontSize - 1)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: settings.fontSize < 24
                      ? () => settings.setFontSize(settings.fontSize + 1)
                      : null,
                ),
              ],
            ),
          ),

          // Commands section
          const _SectionHeader('COMMANDS'),
          ListTile(
            leading: const Icon(Icons.apps),
            title: const Text('Quick Commands'),
            subtitle: Text('${settings.quickCommands.length} commands'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _CommandsEditor()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.filter_list),
            title: const Text('Category Filter'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _CategoryFilter()),
            ),
          ),

          // Behavior section
          const _SectionHeader('BEHAVIOR'),
          SwitchListTile(
            title: const Text('Haptic Feedback'),
            value: settings.hapticFeedback,
            onChanged: (v) => settings.setHapticFeedback(v),
          ),

          // Reset
          const _SectionHeader(''),
          ListTile(
            leading: const Icon(Icons.restore, color: Colors.red),
            title: const Text('Reset Commands', style: TextStyle(color: Colors.red)),
            onTap: () => _showResetDialog(context, settings),
          ),

          // About
          const _SectionHeader('ABOUT'),
          const ListTile(
            title: Text('Version'),
            trailing: Text('1.0.0'),
          ),
          const ListTile(
            title: Text('TermLinkky'),
            subtitle: Text('Remote terminal for developers'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, SettingsManager settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Commands?'),
        content: const Text('This will restore all commands to defaults.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              settings.resetToDefaults();
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 1,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _CommandsEditor extends StatelessWidget {
  const _CommandsEditor();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsManager>();

    return Scaffold(
      appBar: AppBar(title: const Text('Quick Commands')),
      body: ReorderableListView.builder(
        itemCount: settings.quickCommands.length,
        onReorder: (oldIndex, newIndex) {
          // TODO: Implement reorder
        },
        itemBuilder: (context, index) {
          final command = settings.quickCommands[index];
          return Dismissible(
            key: Key(command.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => settings.removeCommand(command),
            child: ListTile(
              leading: Icon(Icons.terminal, color: Theme.of(context).colorScheme.primary),
              title: Text(command.name),
              subtitle: Text(
                command.command,
                style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              trailing: command.isBuiltIn
                  ? Text('Built-in', style: TextStyle(fontSize: 10, color: Colors.grey[600]))
                  : null,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add command dialog
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsManager>();

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: ListView(
        children: CommandCategory.values.map((category) {
          return SwitchListTile(
            title: Text(category.label),
            secondary: Icon(_getCategoryIcon(category)),
            value: settings.enabledCategories.contains(category),
            onChanged: (_) => settings.toggleCategory(category),
          );
        }).toList(),
      ),
    );
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
