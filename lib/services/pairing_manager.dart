import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import '../models/paired_device.dart';

enum PairingState {
  idle,
  connecting,
  awaitingCode,
  verifying,
  paired,
  error,
}

class PairingManager extends ChangeNotifier {
  PairingState _state = PairingState.idle;
  List<PairedDevice> _pairedDevices = [];
  String? _pendingFingerprint;
  String? _errorMessage;

  PairingState get state => _state;
  List<PairedDevice> get pairedDevices => _pairedDevices;
  String? get errorMessage => _errorMessage;

  PairingManager() {
    _loadPairedDevices();
  }

  Future<void> _loadPairedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final devicesJson = prefs.getString('paired_devices');
      if (devicesJson != null) {
        final List<dynamic> decoded = jsonDecode(devicesJson);
        _pairedDevices = decoded.map((d) => PairedDevice.fromJson(d)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading paired devices: $e');
      // Don't crash - just start with empty list
      _pairedDevices = [];
    }
  }

  Future<void> _savePairedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_pairedDevices.map((d) => d.toJson()).toList());
    await prefs.setString('paired_devices', encoded);
  }

  void addPairedDevice(PairedDevice device) {
    _pairedDevices.removeWhere(
        (d) => d.certificateFingerprint == device.certificateFingerprint);
    _pairedDevices.add(device);
    _savePairedDevices();
    notifyListeners();
  }

  void removePairedDevice(PairedDevice device) {
    _pairedDevices.removeWhere((d) => d.id == device.id);
    _savePairedDevices();
    notifyListeners();
  }

  void updateLastConnected(PairedDevice device) {
    final index = _pairedDevices.indexWhere((d) => d.id == device.id);
    if (index != -1) {
      _pairedDevices[index] = device.copyWith(lastConnected: DateTime.now());
      _savePairedDevices();
      notifyListeners();
    }
  }

  Future<void> startPairing(String host, int port, String name) async {
    debugPrint('[PAIRING] startPairing called: $host:$port ($name)');
    _state = PairingState.connecting;
    _errorMessage = null;
    notifyListeners();
    debugPrint('[PAIRING] State: connecting');

    try {
      // Connect and get certificate fingerprint
      debugPrint('[PAIRING] Fetching fingerprint...');
      final fingerprint = await _fetchServerFingerprint(host, port);
      debugPrint('[PAIRING] Got fingerprint: ${fingerprint.substring(0, 20)}...');
      _pendingFingerprint = fingerprint;
      _state = PairingState.awaitingCode;
      debugPrint('[PAIRING] State: awaitingCode');
      notifyListeners();
    } catch (e, stack) {
      debugPrint('[PAIRING] ERROR: $e');
      debugPrint('[PAIRING] Stack: $stack');
      _state = PairingState.error;
      _errorMessage = 'Could not connect: $e';
      notifyListeners();
    }
  }

  void verifyPairingCode(String code, String name, String host, int port) {
    debugPrint('[PAIRING] verifyPairingCode called with: $code');
    if (_pendingFingerprint == null) {
      debugPrint('[PAIRING] ERROR: No pending fingerprint!');
      _state = PairingState.error;
      _errorMessage = 'No pending pairing';
      notifyListeners();
      return;
    }

    _state = PairingState.verifying;
    debugPrint('[PAIRING] State: verifying');
    notifyListeners();

    final pairingCode = PairingCode.fromFingerprint(_pendingFingerprint!);
    
    debugPrint('[PAIRING] === CODE CHECK ===');
    debugPrint('[PAIRING] Fingerprint: ${_pendingFingerprint!.substring(0, 30)}...');
    debugPrint('[PAIRING] Expected: ${pairingCode.code}');
    debugPrint('[PAIRING] Entered: $code');
    debugPrint('[PAIRING] Match: ${pairingCode.verify(code)}');

    if (pairingCode.verify(code)) {
      debugPrint('[PAIRING] Code verified! Creating device...');
      final device = PairedDevice(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        hostname: host,
        port: port,
        certificateFingerprint: _pendingFingerprint!,
        pairedAt: DateTime.now(),
      );
      debugPrint('[PAIRING] Adding device: ${device.name}');
      addPairedDevice(device);
      _state = PairingState.paired;
      debugPrint('[PAIRING] State: paired - SUCCESS!');
      _pendingFingerprint = null;
    } else {
      debugPrint('[PAIRING] Code mismatch!');
      _state = PairingState.error;
      _errorMessage = 'Invalid pairing code. Please check the code on your server.';
    }
    notifyListeners();
  }

  void cancelPairing() {
    _pendingFingerprint = null;
    _errorMessage = null;
    _state = PairingState.idle;
    notifyListeners();
  }

  Future<String> _fetchServerFingerprint(String host, int port) async {
    // Create a secure socket connection to get the certificate with timeout
    final socket = await SecureSocket.connect(
      host,
      port,
      onBadCertificate: (cert) => true, // Accept any cert during pairing
      timeout: const Duration(seconds: 10),
    );

    try {
      final cert = socket.peerCertificate;
      if (cert == null) throw Exception('No certificate received');

      // Calculate SHA-256 fingerprint
      final derBytes = cert.der;
      final digest = sha256.convert(derBytes);
      final fingerprint = digest.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(':');

      return fingerprint;
    } finally {
      await socket.close();
    }
  }
}
