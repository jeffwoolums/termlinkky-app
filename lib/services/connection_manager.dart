import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:crypto/crypto.dart';
import '../models/paired_device.dart';
import '../models/terminal_line.dart';
import 'pairing_manager.dart';

enum AppConnectionState { disconnected, connecting, connected, error }

class ConnectionManager extends ChangeNotifier {
  AppConnectionState _state = AppConnectionState.disconnected;
  PairedDevice? _currentDevice;
  final List<TerminalLine> _terminalLines = [];
  IOWebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String? _errorMessage;
  int _lineCounter = 0;

  AppConnectionState get state => _state;
  PairedDevice? get currentDevice => _currentDevice;
  List<TerminalLine> get terminalLines => _terminalLines;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _state == AppConnectionState.connected;

  Future<void> connect(PairedDevice device, PairingManager pairingManager) async {
    if (_state == AppConnectionState.connecting) return;

    _state = AppConnectionState.connecting;
    _currentDevice = device;
    _terminalLines.clear();
    _errorMessage = null;
    notifyListeners();

    try {
      await _establishSecureConnection(device);
      _state = AppConnectionState.connected;
      pairingManager.updateLastConnected(device);
      _startReceiving();
      notifyListeners();
    } catch (e) {
      _state = AppConnectionState.error;
      _errorMessage = e.toString();
      _currentDevice = null;
      notifyListeners();
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _currentDevice = null;
    _state = AppConnectionState.disconnected;
    notifyListeners();
  }

  Future<void> _establishSecureConnection(PairedDevice device) async {
    final uri = Uri.parse('wss://${device.hostname}:${device.port}/terminal');
    
    final httpClient = HttpClient()
      ..badCertificateCallback = (cert, host, port) {
        final digest = sha256.convert(cert.der);
        final fingerprint = digest.bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(':');
        return fingerprint.toLowerCase() == 
               device.certificateFingerprint.toLowerCase();
      };

    final socket = await WebSocket.connect(
      uri.toString(),
      customClient: httpClient,
    );
    
    _channel = IOWebSocketChannel(socket);
  }

  void _startReceiving() {
    _subscription = _channel?.stream.listen(
      (data) {
        if (data is String) {
          _handleOutput(data);
        }
      },
      onError: (error) {
        _state = AppConnectionState.error;
        _errorMessage = error.toString();
        notifyListeners();
      },
      onDone: () {
        if (_state == AppConnectionState.connected) {
          _state = AppConnectionState.disconnected;
          notifyListeners();
        }
      },
    );
  }

  void _handleOutput(String data) {
    final lines = data.split('\n');
    for (final line in lines) {
      if (line.isNotEmpty) {
        _terminalLines.add(TerminalLine(
          id: '${_lineCounter++}',
          text: line,
        ));
      }
    }
    if (_terminalLines.length > 1000) {
      _terminalLines.removeRange(0, 100);
    }
    notifyListeners();
  }

  void sendCommand(String command) {
    if (!isConnected) return;
    
    _terminalLines.add(TerminalLine(
      id: '${_lineCounter++}',
      text: '\$ $command',
    ));
    notifyListeners();
    
    _channel?.sink.add('$command\n');
  }

  void sendRawInput(String text) {
    if (!isConnected) return;
    _channel?.sink.add(text);
  }

  void clearTerminal() {
    _terminalLines.clear();
    notifyListeners();
  }
}
