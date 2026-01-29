import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:termlinkky/models/terminal_line.dart';

void main() {
  group('AnsiParser', () {
    test('parses plain text without escapes', () {
      final segments = AnsiParser.parse('Hello, World!');
      
      expect(segments.length, 1);
      expect(segments[0].text, 'Hello, World!');
      expect(segments[0].foreground, isNull);
      expect(segments[0].bold, false);
    });

    test('parses red foreground color', () {
      final segments = AnsiParser.parse('\x1B[31mRed Text\x1B[0m');
      
      expect(segments.length, 1);
      expect(segments[0].text, 'Red Text');
      expect(segments[0].foreground, Colors.red);
    });

    test('parses bold text', () {
      final segments = AnsiParser.parse('\x1B[1mBold\x1B[0m');
      
      expect(segments.length, 1);
      expect(segments[0].text, 'Bold');
      expect(segments[0].bold, true);
    });

    test('parses multiple segments with different colors', () {
      final segments = AnsiParser.parse('\x1B[31mRed\x1B[0m Normal \x1B[32mGreen\x1B[0m');
      
      expect(segments.length, 3);
      expect(segments[0].text, 'Red');
      expect(segments[0].foreground, Colors.red);
      expect(segments[1].text, ' Normal ');
      expect(segments[1].foreground, isNull);
      expect(segments[2].text, 'Green');
      expect(segments[2].foreground, Colors.green);
    });

    test('handles combined attributes', () {
      final segments = AnsiParser.parse('\x1B[1;31mBold Red\x1B[0m');
      
      expect(segments.length, 1);
      expect(segments[0].text, 'Bold Red');
      expect(segments[0].bold, true);
      expect(segments[0].foreground, Colors.red);
    });

    test('strips cursor movement escapes', () {
      // Cursor up, down, forward, back
      final segments = AnsiParser.parse('Start\x1B[A\x1B[B\x1B[C\x1B[DEnd');
      
      expect(segments.length, 1);
      expect(segments[0].text, 'StartEnd');
    });

    test('strips screen clear escapes', () {
      final segments = AnsiParser.parse('\x1B[2JCleared');
      
      expect(segments.length, 1);
      expect(segments[0].text, 'Cleared');
    });

    test('strips OSC sequences (terminal title)', () {
      final segments = AnsiParser.parse('\x1B]0;Title\x07Visible');
      
      expect(segments.length, 1);
      expect(segments[0].text, 'Visible');
    });

    test('handles empty string', () {
      final segments = AnsiParser.parse('');
      
      expect(segments.length, 1);
      expect(segments[0].text, '');
    });

    test('handles malformed escape gracefully', () {
      // Incomplete escape sequence - should not crash
      final segments = AnsiParser.parse('\x1B[Text');
      
      // Should return something without crashing
      expect(segments, isNotEmpty);
      // The exact handling may vary, just verify no crash
    });

    test('parses bright colors', () {
      final segments = AnsiParser.parse('\x1B[91mBright Red\x1B[0m');
      
      expect(segments.length, 1);
      expect(segments[0].text, 'Bright Red');
      // Bright red is Color(0xFFFF6B6B)
      expect(segments[0].foreground, isNotNull);
    });

    test('resets all attributes with code 0', () {
      final segments = AnsiParser.parse('\x1B[1;4;31mStyled\x1B[0mPlain');
      
      expect(segments.length, 2);
      expect(segments[0].bold, true);
      expect(segments[0].underline, true);
      expect(segments[1].bold, false);
      expect(segments[1].underline, false);
      expect(segments[1].foreground, isNull);
    });
  });

  group('TerminalLine', () {
    test('creates with timestamp', () {
      final line = TerminalLine(id: '1', text: 'Test');
      
      expect(line.id, '1');
      expect(line.text, 'Test');
      expect(line.timestamp, isNotNull);
    });

    test('parses text on creation', () {
      final line = TerminalLine(id: '1', text: '\x1B[32mGreen\x1B[0m');
      
      expect(line.segments.length, 1);
      expect(line.segments[0].text, 'Green');
      expect(line.segments[0].foreground, Colors.green);
    });
  });
}
