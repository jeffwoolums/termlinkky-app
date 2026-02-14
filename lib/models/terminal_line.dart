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
  // Match color/style codes specifically
  static final _colorPattern = RegExp(r'\x1B\[([0-9;]*)m');
  
  // Match ALL escape sequences (to strip them)
  // This catches: CSI sequences, OSC sequences, cursor movement, etc.
  static final _allEscapePattern = RegExp(
    r'\x1B'  // ESC character
    r'(?:'
      r'\[[0-9;?]*[A-Za-z]'  // CSI sequences (cursor, clear, scroll, etc.)
      r'|'
      r'\][^\x07\x1B]*(?:\x07|\x1B\\)'  // OSC sequences (title, etc.)
      r'|'
      r'[PX^_][^\x1B]*\x1B\\'  // DCS, SOS, PM, APC sequences
      r'|'
      r'[\(\)][AB012]'  // Character set selection
      r'|'
      r'[=>NMOFH78]'  // Single-character sequences
    r')'
  );

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
    // Fail-safe: if anything goes wrong, just return plain text
    try {
      return _parseInternal(text);
    } catch (e) {
      // Strip all escape sequences and return plain text
      final plainText = text.replaceAll(RegExp(r'\x1B\[[0-9;?]*[A-Za-z]|\x1B.'), '');
      return [StyledSegment(text: plainText)];
    }
  }

  static List<StyledSegment> _parseInternal(String text) {
    final segments = <StyledSegment>[];
    Color? foreground;
    Color? background;
    bool bold = false;
    bool italic = false;
    bool underline = false;

    // First, strip all non-color escape sequences (cursor movement, screen clearing, etc.)
    // Keep only color codes for processing
    String cleanedText = text;
    
    // Find all escape sequences and categorize them
    final allMatches = _allEscapePattern.allMatches(text).toList();
    
    // Remove non-color escapes by building clean string
    if (allMatches.isNotEmpty) {
      final buffer = StringBuffer();
      int pos = 0;
      for (final match in allMatches) {
        // Add text before this escape
        if (match.start > pos) {
          buffer.write(text.substring(pos, match.start));
        }
        // Only keep color codes (they end with 'm')
        final seq = match.group(0) ?? '';
        if (seq.endsWith('m') && seq.contains(RegExp(r'\x1B\[[0-9;]*m'))) {
          buffer.write(seq);
        }
        // Skip non-color escapes (cursor movement, etc.)
        pos = match.end;
      }
      // Add remaining text
      if (pos < text.length) {
        buffer.write(text.substring(pos));
      }
      cleanedText = buffer.toString();
    }

    int lastEnd = 0;
    for (final match in _colorPattern.allMatches(cleanedText)) {
      // Add text before this match
      if (match.start > lastEnd) {
        final beforeText = cleanedText.substring(lastEnd, match.start);
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

      // Parse codes - handle 24-bit RGB colors (38;2;R;G;B and 48;2;R;G;B)
      final codeList = match.group(1)?.split(';').map(int.tryParse).toList() ?? [];
      int i = 0;
      while (i < codeList.length) {
        final code = codeList[i];
        if (code == null) { i++; continue; }
        
        // Check for 24-bit RGB foreground: 38;2;R;G;B
        if (code == 38 && i + 4 < codeList.length && codeList[i + 1] == 2) {
          final r = codeList[i + 2] ?? 0;
          final g = codeList[i + 3] ?? 0;
          final b = codeList[i + 4] ?? 0;
          foreground = Color.fromRGBO(r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255), 1.0);
          i += 5;
          continue;
        }
        
        // Check for 24-bit RGB background: 48;2;R;G;B
        if (code == 48 && i + 4 < codeList.length && codeList[i + 1] == 2) {
          final r = codeList[i + 2] ?? 0;
          final g = codeList[i + 3] ?? 0;
          final b = codeList[i + 4] ?? 0;
          background = Color.fromRGBO(r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255), 1.0);
          i += 5;
          continue;
        }
        
        // Check for 256-color: 38;5;N or 48;5;N (just skip these for now)
        if ((code == 38 || code == 48) && i + 2 < codeList.length && codeList[i + 1] == 5) {
          i += 3;
          continue;
        }
        
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
        i++;
      }

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < cleanedText.length) {
      final remaining = cleanedText.substring(lastEnd);
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

    return segments.isEmpty ? [StyledSegment(text: cleanedText)] : segments;
  }
}
