/// Represents an AI coding session running on the server
class AISession {
  final String name;
  final String tmuxSession;
  final AISessionType type;
  final AISessionStatus status;
  final String? lastOutput;
  final DateTime? startedAt;

  const AISession({
    required this.name,
    required this.tmuxSession,
    required this.type,
    this.status = AISessionStatus.unknown,
    this.lastOutput,
    this.startedAt,
  });

  factory AISession.fromTmuxLine(String line) {
    // Parse tmux list-sessions output: "session_name: 1 windows (created Mon Jan 28 12:00:00 2026)"
    final parts = line.split(':');
    final name = parts[0].trim();
    
    // Try to detect AI type from session name
    AISessionType type = AISessionType.unknown;
    if (name.contains('claude')) type = AISessionType.claudeCode;
    else if (name.contains('codex')) type = AISessionType.codex;
    else if (name.contains('aider')) type = AISessionType.aider;
    else if (name.contains('cursor')) type = AISessionType.cursor;
    
    return AISession(
      name: name,
      tmuxSession: name,
      type: type,
      status: AISessionStatus.running,
    );
  }

  String get displayName {
    switch (type) {
      case AISessionType.claudeCode:
        return '🧠 $name';
      case AISessionType.codex:
        return '✨ $name';
      case AISessionType.aider:
        return '🔧 $name';
      case AISessionType.cursor:
        return '📝 $name';
      case AISessionType.unknown:
        return '💻 $name';
    }
  }

  String get typeLabel {
    switch (type) {
      case AISessionType.claudeCode:
        return 'Claude Code';
      case AISessionType.codex:
        return 'Codex';
      case AISessionType.aider:
        return 'Aider';
      case AISessionType.cursor:
        return 'Cursor';
      case AISessionType.unknown:
        return 'Terminal';
    }
  }
}

enum AISessionType {
  claudeCode,
  codex,
  aider,
  cursor,
  unknown,
}

enum AISessionStatus {
  running,
  idle,
  waiting, // Waiting for user input
  error,
  unknown,
}

/// Templates for creating new AI sessions
class AISessionTemplate {
  final String name;
  final String command;
  final AISessionType type;
  final String description;

  const AISessionTemplate({
    required this.name,
    required this.command,
    required this.type,
    required this.description,
  });

  static const List<AISessionTemplate> templates = [
    AISessionTemplate(
      name: 'Claude Code',
      command: 'claude',
      type: AISessionType.claudeCode,
      description: 'Anthropic\'s AI coding assistant',
    ),
    AISessionTemplate(
      name: 'Claude Code (Continue)',
      command: 'claude --continue',
      type: AISessionType.claudeCode,
      description: 'Continue previous Claude session',
    ),
    AISessionTemplate(
      name: 'Codex',
      command: 'codex',
      type: AISessionType.codex,
      description: 'OpenAI\'s coding assistant',
    ),
    AISessionTemplate(
      name: 'Aider',
      command: 'aider',
      type: AISessionType.aider,
      description: 'AI pair programming in terminal',
    ),
    AISessionTemplate(
      name: 'Custom Terminal',
      command: '',
      type: AISessionType.unknown,
      description: 'Start a new terminal session',
    ),
  ];
}
