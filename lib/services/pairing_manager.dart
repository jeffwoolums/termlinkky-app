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
    _state = PairingState.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      // Connect and get certificate fingerprint
      final fingerprint = await _fetchServerFingerprint(host, port);
      _pendingFingerprint = fingerprint;
      _state = PairingState.awaitingCode;
      notifyListeners();
    } catch (e) {
      _state = PairingState.error;
      _errorMessage = 'Could not connect: $e';
      notifyListeners();
    }
  }

  void verifyPairingCode(String code, String name, String host, int port) {
    if (_pendingFingerprint == null) {
      _state = PairingState.error;
      _errorMessage = 'No pending pairing';
      notifyListeners();
      return;
    }

    _state = PairingState.verifying;
    notifyListeners();

    final pairingCode = PairingCode.fromFingerprint(_pendingFingerprint!);
    
    // DEBUG: Show what codes we're comparing
    debugPrint('=== PAIRING DEBUG ===');
    debugPrint('Fingerprint: ${_pendingFingerprint!.substring(0, 30)}...');
    debugPrint('Expected code: ${pairingCode.code}');
    debugPrint('Entered code: $code');
    debugPrint('=====================');

    if (pairingCode.verify(code)) {
      final device = PairedDevice(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        hostname: host,
        port: port,
        certificateFingerprint: _pendingFingerprint!,
        pairedAt: DateTime.now(),
      );
      addPairedDevice(device);
      _state = PairingState.paired;
      _pendingFingerprint = null;
    } else {
      _state = PairingState.error;
      // Show expected code in error for debugging
      _errorMessage = 'Invalid code. Expected: ${pairingCode.code}';
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
    // Create a secure socket connection to get the certificate
    final socket = await SecureSocket.connect(
      host,
      port,
      onBadCertificate: (cert) => true, // Accept any cert during pairing
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
