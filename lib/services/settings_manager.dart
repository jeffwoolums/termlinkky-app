import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quick_command.dart';

class SettingsManager extends ChangeNotifier {
  List<QuickCommand> _quickCommands = [];
  double _fontSize = 14.0;
  bool _showTimestamps = false;
  bool _hapticFeedback = true;
  bool _autoReconnect = true;
  bool _keepScreenOn = true;
  Set<CommandCategory> _enabledCategories = CommandCategory.values.toSet();

  List<QuickCommand> get quickCommands => _quickCommands;
  double get fontSize => _fontSize;
  bool get showTimestamps => _showTimestamps;
  bool get hapticFeedback => _hapticFeedback;
  bool get autoReconnect => _autoReconnect;
  bool get keepScreenOn => _keepScreenOn;
  Set<CommandCategory> get enabledCategories => _enabledCategories;

  List<QuickCommand> get filteredCommands =>
      _quickCommands.where((c) => _enabledCategories.contains(c.category)).toList();

  Map<CommandCategory, List<QuickCommand>> get commandsByCategory {
    final filtered = filteredCommands;
    final grouped = <CommandCategory, List<QuickCommand>>{};
    for (final category in CommandCategory.values) {
      final cmds = filtered.where((c) => c.category == category).toList();
      if (cmds.isNotEmpty) grouped[category] = cmds;
    }
    return grouped;
  }

  SettingsManager() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load commands
      final commandsJson = prefs.getString('quick_commands');
      if (commandsJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(commandsJson);
          _quickCommands = decoded.map((c) => QuickCommand.fromJson(c)).toList();
        } catch (e) {
          debugPrint('Error parsing quick commands: $e');
          _quickCommands = QuickCommand.builtInCommands;
        }
      } else {
        _quickCommands = QuickCommand.builtInCommands;
        _saveCommands();
      }

      // Load settings with safe defaults
      _fontSize = prefs.getDouble('font_size') ?? 14.0;
      _showTimestamps = prefs.getBool('show_timestamps') ?? false;
      _hapticFeedback = prefs.getBool('haptic_feedback') ?? true;
      _autoReconnect = prefs.getBool('auto_reconnect') ?? true;
      _keepScreenOn = prefs.getBool('keep_screen_on') ?? true;

      final categoriesJson = prefs.getStringList('enabled_categories');
      if (categoriesJson != null) {
        _enabledCategories = categoriesJson
            .map((c) => CommandCategory.values.firstWhere(
                  (cat) => cat.name == c,
                  orElse: () => CommandCategory.custom,
                ))
            .toSet();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
      // Use defaults - don't crash
      _quickCommands = QuickCommand.builtInCommands;
    }
  }

  Future<void> _saveCommands() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_quickCommands.map((c) => c.toJson()).toList());
    await prefs.setString('quick_commands', encoded);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size', _fontSize);
    await prefs.setBool('show_timestamps', _showTimestamps);
    await prefs.setBool('haptic_feedback', _hapticFeedback);
    await prefs.setBool('auto_reconnect', _autoReconnect);
    await prefs.setBool('keep_screen_on', _keepScreenOn);
    await prefs.setStringList(
        'enabled_categories', _enabledCategories.map((c) => c.name).toList());
  }

  void addCommand(QuickCommand command) {
    _quickCommands.add(command);
    _saveCommands();
    notifyListeners();
  }

  void removeCommand(QuickCommand command) {
    _quickCommands.removeWhere((c) => c.id == command.id);
    _saveCommands();
    notifyListeners();
  }

  void updateCommand(QuickCommand command) {
    final index = _quickCommands.indexWhere((c) => c.id == command.id);
    if (index != -1) {
      _quickCommands[index] = command;
      _saveCommands();
      notifyListeners();
    }
  }

  void resetToDefaults() {
    _quickCommands = QuickCommand.builtInCommands;
    _saveCommands();
    notifyListeners();
  }

  void setFontSize(double size) {
    _fontSize = size;
    _saveSettings();
    notifyListeners();
  }

  void toggleCategory(CommandCategory category) {
    if (_enabledCategories.contains(category)) {
      _enabledCategories.remove(category);
    } else {
      _enabledCategories.add(category);
    }
    _saveSettings();
    notifyListeners();
  }

  void setHapticFeedback(bool value) {
    _hapticFeedback = value;
    _saveSettings();
    notifyListeners();
  }
}
