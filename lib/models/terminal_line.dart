import 'package:flutter/material.dart';

class TerminalLine {
  final String id;
  final String text;
  final DateTime timestamp;
  final List<StyledSegment> segments;

  TerminalLine({
    required this.id,
    required this.text,
    DateTime? timestamp,
  })  : timestamp = timestamp ?? DateTime.now(),
        segments = AnsiParser.parse(text);
}

class StyledSegment {
  final String text;
  final Color? foreground;
  final Color? background;
  final bool bold;
  final bool italic;
  final bool underline;

  const StyledSegment({
    required this.text,
    this.foreground,
    this.background,
    this.bold = false,
    this.italic = false,
    this.underline = false,
  });
}

class AnsiParser {
  static final _ansiPattern = RegExp(r'\x1B\[([0-9;]*)m');

  static const _colors = {
    30: Colors.black,
    31: Colors.red,
    32: Colors.green,
    33: Colors.yellow,
    34: Colors.blue,
    35: Colors.purple,
    36: Colors.cyan,
    37: Colors.white,
    90: Colors.grey,
    91: Color(0xFFFF6B6B),
    92: Color(0xFF6BFF6B),
    93: Color(0xFFFFFF6B),
    94: Color(0xFF6B6BFF),
    95: Color(0xFFFF6BFF),
    96: Color(0xFF6BFFFF),
    97: Colors.white,
  };

  static List<StyledSegment> parse(String text) {
    final segments = <StyledSegment>[];
    Color? foreground;
    Color? background;
    bool bold = false;
    bool italic = false;
    bool underline = false;

    int lastEnd = 0;
    for (final match in _ansiPattern.allMatches(text)) {
      // Add text before this match
      if (match.start > lastEnd) {
        final beforeText = text.substring(lastEnd, match.start);
        if (beforeText.isNotEmpty) {
          segments.add(StyledSegment(
            text: beforeText,
            foreground: foreground,
            background: background,
            bold: bold,
            italic: italic,
            underline: underline,
          ));
        }
      }

      // Parse codes
      final codes = match.group(1)?.split(';').map(int.tryParse).whereType<int>() ?? [];
      for (final code in codes) {
        switch (code) {
          case 0:
            foreground = null;
            background = null;
            bold = false;
            italic = false;
            underline = false;
          case 1:
            bold = true;
          case 3:
            italic = true;
          case 4:
            underline = true;
          case 22:
            bold = false;
          case 23:
            italic = false;
          case 24:
            underline = false;
          case 39:
            foreground = null;
          case 49:
            background = null;
          default:
            if (_colors.containsKey(code)) {
              foreground = _colors[code];
            } else if (code >= 40 && code <= 47) {
              background = _colors[code - 10];
            }
        }
      }

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      final remaining = text.substring(lastEnd);
      if (remaining.isNotEmpty) {
        segments.add(StyledSegment(
          text: remaining,
          foreground: foreground,
          background: background,
          bold: bold,
          italic: italic,
          underline: underline,
        ));
      }
    }

    return segments.isEmpty ? [StyledSegment(text: text)] : segments;
  }
}
