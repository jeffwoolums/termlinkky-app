import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum AIProvider { claude, openai }

class AIMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final List<String>? suggestedCommands;
  final DateTime timestamp;

  AIMessage({
    required this.id,
    required this.role,
    required this.content,
    this.suggestedCommands,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AIAssistant extends ChangeNotifier {
  AIProvider _provider = AIProvider.claude;
  String? _apiKey;
  final List<AIMessage> _messages = [];
  bool _isLoading = false;
  String? _error;
  String? _workingDirectory;
  List<String> _recentOutput = [];

  AIProvider get provider => _provider;
  String? get apiKey => _apiKey;
  List<AIMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  AIAssistant() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('ai_api_key');
    final providerStr = prefs.getString('ai_provider');
    if (providerStr == 'openai') _provider = AIProvider.openai;
    notifyListeners();
  }

  Future<void> setApiKey(String key, AIProvider provider) async {
    _apiKey = key;
    _provider = provider;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_api_key', key);
    await prefs.setString('ai_provider', provider.name);
    notifyListeners();
  }

  void setContext({String? workingDirectory, List<String>? recentOutput}) {
    _workingDirectory = workingDirectory;
    if (recentOutput != null) _recentOutput = recentOutput;
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  Future<AIMessage?> sendMessage(String userMessage) async {
    if (!isConfigured) {
      _error = 'API key not configured';
      notifyListeners();
      return null;
    }

    // Add user message
    final userMsg = AIMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: userMessage,
    );
    _messages.add(userMsg);
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _callAI(userMessage);
      final assistantMsg = AIMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_resp',
        role: 'assistant',
        content: response.explanation,
        suggestedCommands: response.commands,
      );
      _messages.add(assistantMsg);
      _isLoading = false;
      notifyListeners();
      return assistantMsg;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<_AIResponse> _callAI(String userMessage) async {
    final systemPrompt = '''You are TermLinky AI, a terminal assistant. The user is remotely connected to their workstation and needs help executing commands.

Your job:
1. Understand what the user wants to accomplish
2. Suggest the exact shell commands to achieve it
3. Explain briefly what each command does

Context:
- Working directory: ${_workingDirectory ?? 'unknown'}
- Recent terminal output: ${_recentOutput.take(20).join('\n')}

IMPORTANT: Respond in this exact JSON format:
{
  "explanation": "Brief explanation of what you'll do",
  "commands": ["command1", "command2"]
}

Only suggest commands that are safe and relevant. If the request is unclear, ask for clarification in the explanation and leave commands empty.''';

    if (_provider == AIProvider.claude) {
      return _callClaude(systemPrompt, userMessage);
    } else {
      return _callOpenAI(systemPrompt, userMessage);
    }
  }

  Future<_AIResponse> _callClaude(String systemPrompt, String userMessage) async {
    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey!,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': 'claude-sonnet-4-20250514',
        'max_tokens': 1024,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': userMessage}
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Claude API error: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['content'][0]['text'];
    return _parseResponse(content);
  }

  Future<_AIResponse> _callOpenAI(String systemPrompt, String userMessage) async {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenAI API error: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'];
    return _parseResponse(content);
  }

  _AIResponse _parseResponse(String content) {
    try {
      // Try to extract JSON from the response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch != null) {
        final json = jsonDecode(jsonMatch.group(0)!);
        return _AIResponse(
          explanation: json['explanation'] ?? content,
          commands: (json['commands'] as List?)?.cast<String>() ?? [],
        );
      }
    } catch (_) {}
    
    // Fallback: treat entire response as explanation
    return _AIResponse(explanation: content, commands: []);
  }
}

class _AIResponse {
  final String explanation;
  final List<String> commands;
  _AIResponse({required this.explanation, required this.commands});
}
