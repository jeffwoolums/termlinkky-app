import 'package:flutter_test/flutter_test.dart';
import 'package:termlinkky/models/paired_device.dart';
import 'package:termlinkky/models/quick_command.dart';
import 'package:termlinkky/models/ai_session.dart';

void main() {
  group('PairedDevice', () {
    test('creates device with required fields', () {
      final device = PairedDevice(
        id: '123',
        name: 'My Mac',
        hostname: '100.70.5.93',
        port: 8443,
        certificateFingerprint: 'aa:bb:cc',
        pairedAt: DateTime(2026, 1, 28),
      );

      expect(device.id, '123');
      expect(device.name, 'My Mac');
      expect(device.hostname, '100.70.5.93');
      expect(device.port, 8443);
    });

    test('displayAddress formats correctly', () {
      final device = PairedDevice(
        id: '123',
        name: 'Test',
        hostname: '192.168.1.100',
        port: 8443,
        certificateFingerprint: 'aa:bb',
        pairedAt: DateTime.now(),
      );

      expect(device.displayAddress, '192.168.1.100:8443');
    });

    test('serializes to JSON', () {
      final device = PairedDevice(
        id: '123',
        name: 'My Mac',
        hostname: '100.70.5.93',
        port: 8443,
        certificateFingerprint: 'aa:bb:cc',
        pairedAt: DateTime(2026, 1, 28, 12, 0, 0),
      );

      final json = device.toJson();

      expect(json['id'], '123');
      expect(json['name'], 'My Mac');
      expect(json['hostname'], '100.70.5.93');
      expect(json['port'], 8443);
      expect(json['certificateFingerprint'], 'aa:bb:cc');
    });

    test('deserializes from JSON', () {
      final json = {
        'id': '456',
        'name': 'Work Mac',
        'hostname': '10.0.0.1',
        'port': 9000,
        'certificateFingerprint': 'dd:ee:ff',
        'pairedAt': '2026-01-28T10:00:00.000',
      };

      final device = PairedDevice.fromJson(json);

      expect(device.id, '456');
      expect(device.name, 'Work Mac');
      expect(device.hostname, '10.0.0.1');
      expect(device.port, 9000);
    });

    test('copyWith creates new instance with updated fields', () {
      final original = PairedDevice(
        id: '1',
        name: 'Original',
        hostname: '1.1.1.1',
        port: 8443,
        certificateFingerprint: 'abc',
        pairedAt: DateTime(2026, 1, 1),
      );

      final updated = original.copyWith(name: 'Updated');

      expect(updated.name, 'Updated');
      expect(updated.id, '1'); // Unchanged
      expect(original.name, 'Original'); // Original unchanged
    });
  });

  group('PairingCode', () {
    test('generates consistent code from fingerprint', () {
      final code1 = PairingCode.fromFingerprint('aa:bb:cc:dd:ee:ff');
      final code2 = PairingCode.fromFingerprint('aa:bb:cc:dd:ee:ff');

      expect(code1.code, code2.code);
    });

    test('generates 6-digit code', () {
      final code = PairingCode.fromFingerprint('12:34:56:78:9a:bc');

      expect(code.code.length, 6);
      expect(int.tryParse(code.code), isNotNull);
    });

    test('verifies correct code', () {
      final code = PairingCode.fromFingerprint('aa:bb:cc:dd:ee:ff');

      expect(code.verify(code.code), true);
    });

    test('rejects incorrect code', () {
      final code = PairingCode.fromFingerprint('aa:bb:cc:dd:ee:ff');

      expect(code.verify('000000'), false);
      expect(code.verify('999999'), false);
    });
  });

  group('QuickCommand', () {
    test('creates command with all fields', () {
      final cmd = QuickCommand(
        id: '1',
        name: 'List Files',
        command: 'ls -la',
        category: CommandCategory.system,
        icon: '📁',
      );

      expect(cmd.name, 'List Files');
      expect(cmd.command, 'ls -la');
      expect(cmd.category, CommandCategory.system);
    });

    test('builtInCommands is not empty', () {
      expect(QuickCommand.builtInCommands, isNotEmpty);
    });

    test('builtInCommands has all categories', () {
      final categories = QuickCommand.builtInCommands
          .map((c) => c.category)
          .toSet();

      expect(categories.contains(CommandCategory.system), true);
      expect(categories.contains(CommandCategory.git), true);
    });

    test('serializes to JSON', () {
      final cmd = QuickCommand(
        id: '1',
        name: 'Test',
        command: 'echo test',
        category: CommandCategory.custom,
      );

      final json = cmd.toJson();

      expect(json['name'], 'Test');
      expect(json['command'], 'echo test');
    });
  });

  group('AISession', () {
    test('detects Claude Code session from tmux line', () {
      final session = AISession.fromTmuxLine('claude-session: 1 windows');

      expect(session.type, AISessionType.claudeCode);
      expect(session.name, 'claude-session');
    });

    test('detects Aider session from tmux line', () {
      final session = AISession.fromTmuxLine('aider-project: 2 windows');

      expect(session.type, AISessionType.aider);
    });

    test('detects Codex session from tmux line', () {
      final session = AISession.fromTmuxLine('codex-work: 1 windows');

      expect(session.type, AISessionType.codex);
    });

    test('defaults to unknown for unrecognized names', () {
      final session = AISession.fromTmuxLine('my-random-session: 1 windows');

      expect(session.type, AISessionType.unknown);
    });

    test('typeLabel returns correct label', () {
      final session = AISession(
        name: 'test-session',
        tmuxSession: 'test-session',
        type: AISessionType.claudeCode,
      );

      expect(session.typeLabel, 'Claude Code');
    });

    test('displayName includes emoji', () {
      final session = AISession(
        name: 'test',
        tmuxSession: 'test',
        type: AISessionType.claudeCode,
      );

      expect(session.displayName, contains('🧠'));
    });
  });
}
