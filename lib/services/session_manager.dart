import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/ai_session.dart';
import 'connection_manager.dart';

/// Manages AI/tmux sessions on the remote server
class SessionManager extends ChangeNotifier {
  final ConnectionManager _connectionManager;
  List<AISession> _sessions = [];
  bool _isLoading = false;
  String? _error;
  String? _attachedSession;

  List<AISession> get sessions => _sessions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get attachedSession => _attachedSession;
  bool get isAttached => _attachedSession != null;

  SessionManager(this._connectionManager);

  /// Fetch list of tmux sessions from server
  Future<void> refreshSessions() async {
    if (!_connectionManager.isConnected) {
      _error = 'Not connected';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Send command to list tmux sessions
      _connectionManager.sendCommand('tmux list-sessions 2>/dev/null || echo "NO_SESSIONS"');
      
      // Wait a moment for response
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Parse the output from terminal lines
      final output = _connectionManager.terminalLines
          .map((l) => l.text)
          .where((l) => !l.startsWith('\$'))
          .join('\n');
      
      if (output.contains('NO_SESSIONS') || output.contains('no server running')) {
        _sessions = [];
      } else {
        _sessions = output
            .split('\n')
            .where((line) => line.contains(':') && !line.startsWith('\$'))
            .map((line) => AISession.fromTmuxLine(line))
            .toList();
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Attach to an existing tmux session
  Future<void> attachSession(String sessionName) async {
    if (!_connectionManager.isConnected) return;
    
    _connectionManager.sendCommand('tmux attach-session -t $sessionName');
    _attachedSession = sessionName;
    notifyListeners();
  }

  /// Detach from current tmux session
  void detachSession() {
    if (!_connectionManager.isConnected) return;
    
    // Send Ctrl+B, D to detach from tmux
    _connectionManager.sendRawInput('\x02d');
    _attachedSession = null;
    notifyListeners();
  }

  /// Create a new AI session
  Future<void> createSession(AISessionTemplate template, {String? customName, String? workingDirectory}) async {
    if (!_connectionManager.isConnected) return;
    
    final sessionName = customName ?? '${template.type.name}-${DateTime.now().millisecondsSinceEpoch}';
    
    String command = 'tmux new-session -d -s $sessionName';
    if (workingDirectory != null) {
      command += ' -c "$workingDirectory"';
    }
    command += ' "${template.command}"';
    
    _connectionManager.sendCommand(command);
    
    // Wait and refresh
    await Future.delayed(const Duration(milliseconds: 500));
    await refreshSessions();
    
    // Auto-attach to new session
    await attachSession(sessionName);
  }

  /// Kill a tmux session
  Future<void> killSession(String sessionName) async {
    if (!_connectionManager.isConnected) return;
    
    if (_attachedSession == sessionName) {
      detachSession();
    }
    
    _connectionManager.sendCommand('tmux kill-session -t $sessionName');
    
    await Future.delayed(const Duration(milliseconds: 300));
    await refreshSessions();
  }

  /// Send input to the attached session
  void sendToSession(String input) {
    if (!_connectionManager.isConnected || !isAttached) return;
    _connectionManager.sendRawInput(input);
  }

  /// Send a prompt/message to the AI in the session
  void sendPrompt(String prompt) {
    if (!_connectionManager.isConnected || !isAttached) return;
    _connectionManager.sendCommand(prompt);
  }
}
