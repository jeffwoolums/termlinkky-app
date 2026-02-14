import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

class RealTerminalView extends StatefulWidget {
  final Stream<String> outputStream;
  final Function(String) onInput;
  final Function(int cols, int rows)? onResize;
  
  const RealTerminalView({
    super.key,
    required this.outputStream,
    required this.onInput,
    this.onResize,
  });

  @override
  State<RealTerminalView> createState() => _RealTerminalViewState();
}

class _RealTerminalViewState extends State<RealTerminalView> {
  Terminal? _terminal;
  late TerminalController _terminalController;
  StreamSubscription? _outputSubscription;
  bool _initialized = false;
  final FocusNode _inputFocusNode = FocusNode();
  final TextEditingController _inputController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _terminalController = TerminalController();
    
    // Listen to text changes and send each character
    _inputController.addListener(_onTextChanged);
  }
  
  String _lastText = '';
  
  void _onTextChanged() {
    final newText = _inputController.text;
    if (newText.length > _lastText.length) {
      // New character(s) typed
      final newChars = newText.substring(_lastText.length);
      widget.onInput(newChars);
    } else if (newText.length < _lastText.length) {
      // Backspace pressed
      widget.onInput('\x7f');
    }
    _lastText = newText;
    
    // Keep input field clear to avoid buildup
    if (newText.length > 10) {
      _inputController.clear();
      _lastText = '';
    }
  }
  
  void _initTerminal(int cols, int rows) {
    if (_initialized) return;
    _initialized = true;
    
    _terminal = Terminal(maxLines: 5000);
    
    _outputSubscription = widget.outputStream.listen((data) {
      _terminal?.write(data);
    });
    
    setState(() {});
  }
  
  @override
  void dispose() {
    _outputSubscription?.cancel();
    _terminalController.dispose();
    _inputFocusNode.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _sendSpecialKey(String key) {
    final Map<String, String> keyMap = {
      'enter': '\r',
      'tab': '\t',
      'escape': '\x1b',
      'up': '\x1b[A',
      'down': '\x1b[B',
      'right': '\x1b[C',
      'left': '\x1b[D',
    };
    if (keyMap.containsKey(key)) {
      widget.onInput(keyMap[key]!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const fontSize = 12.0;
        const charWidth = 7.2;
        const charHeight = 15.0;
        
        final cols = (constraints.maxWidth / charWidth).floor().clamp(30, 200);
        final rows = (constraints.maxHeight / charHeight).floor().clamp(10, 100);
        
        if (!_initialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initTerminal(cols, rows);
          });
        }
        
        if (_terminal == null) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4ADE80)),
          );
        }
        
        return Stack(
          children: [
            // Terminal view
            GestureDetector(
              behavior: HitTestBehavior.translucent, // Allow scroll through
              onTap: () {
                _inputFocusNode.requestFocus();
              },
              child: TerminalView(
                _terminal!,
                controller: _terminalController,
                theme: TerminalTheme(
                  cursor: const Color(0xFF4ADE80),
                  selection: const Color(0xFF4ADE80).withValues(alpha: 0.3),
                  foreground: const Color(0xFF00FF00),
                  background: const Color(0xFF000000),
                  black: const Color(0xFF000000),
                  red: const Color(0xFFFF5555),
                  green: const Color(0xFF50FA7B),
                  yellow: const Color(0xFFF1FA8C),
                  blue: const Color(0xFF6272A4),
                  magenta: const Color(0xFFFF79C6),
                  cyan: const Color(0xFF8BE9FD),
                  white: const Color(0xFFBBBBBB),
                  brightBlack: const Color(0xFF555555),
                  brightRed: const Color(0xFFFF6E6E),
                  brightGreen: const Color(0xFF69FF94),
                  brightYellow: const Color(0xFFFFFFA5),
                  brightBlue: const Color(0xFFD6ACFF),
                  brightMagenta: const Color(0xFFFF92DF),
                  brightCyan: const Color(0xFFA4FFFF),
                  brightWhite: const Color(0xFFFFFFFF),
                  searchHitBackground: const Color(0xFFFFE066),
                  searchHitBackgroundCurrent: const Color(0xFFFF6B6B),
                  searchHitForeground: const Color(0xFF000000),
                ),
                textStyle: const TerminalStyle(
                  fontSize: fontSize,
                  fontFamily: 'JetBrainsMono',
                ),
                autofocus: false,
              ),
            ),
            
            // Hidden text field to capture keyboard input
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Opacity(
                opacity: 0.0,
                child: SizedBox(
                  height: 1,
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    autofocus: false,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.none,
                    onSubmitted: (_) {
                      _sendSpecialKey('enter');
                      _inputController.clear();
                      _lastText = '';
                      _inputFocusNode.requestFocus();
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
