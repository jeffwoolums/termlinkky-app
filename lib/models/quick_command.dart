enum CommandCategory {
  ai('AI Agents', 'smart_toy'),
  git('Git', 'account_tree'),
  node('Node.js', 'javascript'),
  python('Python', 'code'),
  docker('Docker', 'inventory_2'),
  system('System', 'settings'),
  files('Files', 'folder'),
  terminal('Terminal', 'terminal'),
  custom('Custom', 'star');

  final String label;
  final String icon;
  const CommandCategory(this.label, this.icon);
}

class QuickCommand {
  final String id;
  final String name;
  final String command;
  final CommandCategory category;
  final String icon;
  final bool isBuiltIn;
  final bool confirmBeforeRun;

  const QuickCommand({
    required this.id,
    required this.name,
    required this.command,
    this.category = CommandCategory.custom,
    this.icon = 'terminal',
    this.isBuiltIn = false,
    this.confirmBeforeRun = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'command': command,
        'category': category.name,
        'icon': icon,
        'isBuiltIn': isBuiltIn,
        'confirmBeforeRun': confirmBeforeRun,
      };

  factory QuickCommand.fromJson(Map<String, dynamic> json) => QuickCommand(
        id: json['id'],
        name: json['name'],
        command: json['command'],
        category: CommandCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => CommandCategory.custom,
        ),
        icon: json['icon'] ?? 'terminal',
        isBuiltIn: json['isBuiltIn'] ?? false,
        confirmBeforeRun: json['confirmBeforeRun'] ?? false,
      );

  static List<QuickCommand> get builtInCommands => const [
        // AI Agents
        QuickCommand(id: 'ai-claude', name: 'Claude Code', command: 'claude', category: CommandCategory.ai, icon: 'psychology', isBuiltIn: true),
        QuickCommand(id: 'ai-claude-c', name: 'Claude (Continue)', command: 'claude --continue', category: CommandCategory.ai, icon: 'psychology', isBuiltIn: true),
        QuickCommand(id: 'ai-codex', name: 'Codex', command: 'codex', category: CommandCategory.ai, icon: 'auto_awesome', isBuiltIn: true),
        QuickCommand(id: 'ai-aider', name: 'Aider', command: 'aider', category: CommandCategory.ai, icon: 'assistant', isBuiltIn: true),
        // Git
        QuickCommand(id: 'git-status', name: 'Status', command: 'git status', category: CommandCategory.git, icon: 'help_outline', isBuiltIn: true),
        QuickCommand(id: 'git-pull', name: 'Pull', command: 'git pull', category: CommandCategory.git, icon: 'download', isBuiltIn: true),
        QuickCommand(id: 'git-push', name: 'Push', command: 'git push', category: CommandCategory.git, icon: 'upload', isBuiltIn: true),
        QuickCommand(id: 'git-log', name: 'Log (10)', command: 'git log --oneline -10', category: CommandCategory.git, icon: 'list', isBuiltIn: true),
        QuickCommand(id: 'git-diff', name: 'Diff', command: 'git diff', category: CommandCategory.git, icon: 'compare_arrows', isBuiltIn: true),
        QuickCommand(id: 'git-stash', name: 'Stash', command: 'git stash', category: CommandCategory.git, icon: 'archive', isBuiltIn: true),
        // Node.js
        QuickCommand(id: 'node-install', name: 'npm install', command: 'npm install', category: CommandCategory.node, icon: 'inventory_2', isBuiltIn: true),
        QuickCommand(id: 'node-dev', name: 'npm run dev', command: 'npm run dev', category: CommandCategory.node, icon: 'play_arrow', isBuiltIn: true),
        QuickCommand(id: 'node-build', name: 'npm run build', command: 'npm run build', category: CommandCategory.node, icon: 'build', isBuiltIn: true),
        QuickCommand(id: 'node-test', name: 'npm test', command: 'npm test', category: CommandCategory.node, icon: 'check_circle', isBuiltIn: true),
        // Python
        QuickCommand(id: 'py-repl', name: 'Python REPL', command: 'python3', category: CommandCategory.python, icon: 'code', isBuiltIn: true),
        QuickCommand(id: 'py-pip', name: 'pip install -r', command: 'pip install -r requirements.txt', category: CommandCategory.python, icon: 'inventory_2', isBuiltIn: true),
        QuickCommand(id: 'py-pytest', name: 'pytest', command: 'pytest', category: CommandCategory.python, icon: 'check_circle', isBuiltIn: true),
        // Docker
        QuickCommand(id: 'docker-ps', name: 'Docker PS', command: 'docker ps', category: CommandCategory.docker, icon: 'list', isBuiltIn: true),
        QuickCommand(id: 'docker-up', name: 'Compose Up', command: 'docker compose up -d', category: CommandCategory.docker, icon: 'play_arrow', isBuiltIn: true),
        QuickCommand(id: 'docker-down', name: 'Compose Down', command: 'docker compose down', category: CommandCategory.docker, icon: 'stop', isBuiltIn: true, confirmBeforeRun: true),
        // System
        QuickCommand(id: 'sys-df', name: 'Disk Usage', command: 'df -h', category: CommandCategory.system, icon: 'storage', isBuiltIn: true),
        QuickCommand(id: 'sys-top', name: 'Top', command: 'top', category: CommandCategory.system, icon: 'monitoring', isBuiltIn: true),
        QuickCommand(id: 'sys-htop', name: 'htop', command: 'htop', category: CommandCategory.system, icon: 'monitoring', isBuiltIn: true),
        QuickCommand(id: 'sys-ps', name: 'Processes', command: 'ps aux | head -20', category: CommandCategory.system, icon: 'memory', isBuiltIn: true),
        // Files
        QuickCommand(id: 'files-ls', name: 'List Files', command: 'ls -la', category: CommandCategory.files, icon: 'list', isBuiltIn: true),
        QuickCommand(id: 'files-tree', name: 'Tree', command: 'tree -L 2', category: CommandCategory.files, icon: 'account_tree', isBuiltIn: true),
        // Terminal
        QuickCommand(id: 'term-clear', name: 'Clear', command: 'clear', category: CommandCategory.terminal, icon: 'clear_all', isBuiltIn: true),
        QuickCommand(id: 'term-exit', name: 'Exit', command: 'exit', category: CommandCategory.terminal, icon: 'exit_to_app', isBuiltIn: true, confirmBeforeRun: true),
        QuickCommand(id: 'term-tmux', name: 'Tmux Sessions', command: 'tmux list-sessions', category: CommandCategory.terminal, icon: 'view_column', isBuiltIn: true),
      ];
}
