import 'dart:convert';

class PairedDevice {
  final String id;
  final String name;
  final String hostname;
  final int port;
  final String certificateFingerprint;
  final DateTime pairedAt;
  DateTime? lastConnected;
  String? tmuxSession;

  PairedDevice({
    required this.id,
    required this.name,
    required this.hostname,
    this.port = 8443,
    required this.certificateFingerprint,
    required this.pairedAt,
    this.lastConnected,
    this.tmuxSession,
  });

  String get displayAddress => '$hostname:$port';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'hostname': hostname,
        'port': port,
        'certificateFingerprint': certificateFingerprint,
        'pairedAt': pairedAt.toIso8601String(),
        'lastConnected': lastConnected?.toIso8601String(),
        'tmuxSession': tmuxSession,
      };

  factory PairedDevice.fromJson(Map<String, dynamic> json) => PairedDevice(
        id: json['id'],
        name: json['name'],
        hostname: json['hostname'],
        port: json['port'] ?? 8443,
        certificateFingerprint: json['certificateFingerprint'],
        pairedAt: DateTime.parse(json['pairedAt']),
        lastConnected: json['lastConnected'] != null
            ? DateTime.parse(json['lastConnected'])
            : null,
        tmuxSession: json['tmuxSession'],
      );

  PairedDevice copyWith({
    String? name,
    String? hostname,
    int? port,
    DateTime? lastConnected,
    String? tmuxSession,
  }) =>
      PairedDevice(
        id: id,
        name: name ?? this.name,
        hostname: hostname ?? this.hostname,
        port: port ?? this.port,
        certificateFingerprint: certificateFingerprint,
        pairedAt: pairedAt,
        lastConnected: lastConnected ?? this.lastConnected,
        tmuxSession: tmuxSession ?? this.tmuxSession,
      );
}

/// Generates a 6-digit pairing code from certificate fingerprint
class PairingCode {
  final String code;
  final String fingerprint;

  PairingCode({required this.code, required this.fingerprint});

  factory PairingCode.fromFingerprint(String fingerprint) {
    final cleanFingerprint = fingerprint.replaceAll(':', '').toLowerCase();
    final hexPart = cleanFingerprint.substring(0, 6);
    final numeric = int.parse(hexPart, radix: 16) % 1000000;
    return PairingCode(
      code: numeric.toString().padLeft(6, '0'),
      fingerprint: fingerprint,
    );
  }

  bool verify(String enteredCode) {
    return code == enteredCode.trim();
  }
}
