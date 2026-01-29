import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:crypto/crypto.dart';
import '../models/paired_device.dart';
import '../models/terminal_line.dart';
import 'pairing_manager.dart';

// Timer is in dart:async, already imported

enum AppConnectionState { disconnected, connecting, connected, error }

class ConnectionManager extends ChangeNotifier {
  AppConnectionState _state = AppConnectionState.disconnected;
  PairedDevice? _currentDevice;
  final List<TerminalLine> _terminalLines = [];
  IOWebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String? _errorMessage;
  int _lineCounter = 0;
  
  // Auto-reconnect
  PairingManager? _pairingManager;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  static const Duration _reconnectDelay = Duration(seconds: 2);
  bool _autoReconnectEnabled = true;
  Timer? _reconnectTimer;

  AppConnectionState get state => _state;
  PairedDevice? get currentDevice => _currentDevice;
  List<TerminalLine> get terminalLines => _terminalLines;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _state == AppConnectionState.connected;

  Future<void> connect(PairedDevice device, PairingManager pairingManager) async {
    if (_state == AppConnectionState.connecting) return;

    _state = AppConnectionState.connecting;
    _currentDevice = device;
    _pairingManager = pairingManager;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _terminalLines.clear();
    _errorMessage = null;
    notifyListeners();

    try {
      await _establishSecureConnection(device);
      _state = AppConnectionState.connected;
      _autoReconnectEnabled = true;
      _reconnectAttempts = 0;
      pairingManager.updateLastConnected(device);
      _startReceiving();
      notifyListeners();
    } catch (e) {
      debugPrint('[CM] Connection failed: $e');
      _state = AppConnectionState.error;
      _errorMessage = e.toString();
      _currentDevice = null;
      notifyListeners();
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _autoReconnectEnabled = false;  // Disable auto-reconnect on manual disconnect
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _currentDevice = null;
    _state = AppConnectionState.disconnected;
    notifyListeners();
  }

  void _attemptReconnect() {
    if (!_autoReconnectEnabled) {
      debugPrint('[CM] Auto-reconnect disabled');
      return;
    }
    if (_currentDevice == null || _pairingManager == null) {
      debugPrint('[CM] No device/pairing manager for reconnect');
      return;
    }
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[CM] Max reconnect attempts reached');
      _errorMessage = 'Connection lost. Tap to reconnect.';
      notifyListeners();
      return;
    }

    _reconnectAttempts++;
    debugPrint('[CM] Scheduling reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay * _reconnectAttempts, () async {
      if (_state == AppConnectionState.disconnected && _currentDevice != null) {
        debugPrint('[CM] Attempting reconnect...');
        _terminalLines.add(TerminalLine(
          id: '${_lineCounter++}',
          text: '--- Reconnecting (attempt $_reconnectAttempts) ---',
        ));
        notifyListeners();
        
        // Re-enable auto-reconnect for this attempt
        _autoReconnectEnabled = true;
        await connect(_currentDevice!, _pairingManager!);
      }
    });
  }
  
  /// Enable auto-reconnect (call after successful manual connect)
  void enableAutoReconnect() {
    _autoReconnectEnabled = true;
    _reconnectAttempts = 0;
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
      onError: (error, stackTrace) {
        debugPrint('[CM] WebSocket error: $error');
        _state = AppConnectionState.error;
        _errorMessage = error.toString();
        notifyListeners();
      },
      onDone: () {
        debugPrint('[CM] WebSocket closed');
        if (_state == AppConnectionState.connected) {
          _state = AppConnectionState.disconnected;
          notifyListeners();
          _attemptReconnect();
        }
      },
      cancelOnError: false,
    );
  }

  void _handleOutput(String data) {
    try {
      final lines = data.split('\n');
      for (final line in lines) {
        if (line.isNotEmpty) {
          _terminalLines.add(TerminalLine(
            id: '${_lineCounter++}',
            text: line,
          ));
        }
      }
      // Trim to max 1000 lines
      if (_terminalLines.length > 1000) {
        _terminalLines.removeRange(0, _terminalLines.length - 1000);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[CM] Error handling output: $e');
    }
  }

  void sendCommand(String command) {
    if (!isConnected) return;
    
    try {
      _terminalLines.add(TerminalLine(
        id: '${_lineCounter++}',
        text: '\$ $command',
      ));
      notifyListeners();
      _channel?.sink.add('$command\n');
    } catch (e) {
      debugPrint('[CM] Error sending command: $e');
    }
  }

  void sendRawInput(String text) {
    if (!isConnected) return;
    _channel?.sink.add(text);
  }

  void clearTerminal() {
    _terminalLines.clear();
    notifyListeners();
  }

  void sendSpecialKey(String key) {
    if (!isConnected) return;
    
    // Map key names to escape sequences
    final Map<String, String> keyMap = {
      'enter': '\r',
      'tab': '\t',
      'escape': '\x1b',
      'up': '\x1b[A',
      'down': '\x1b[B',
      'right': '\x1b[C',
      'left': '\x1b[D',
      'home': '\x1b[H',
      'end': '\x1b[F',
      'pageup': '\x1b[5~',
      'pagedown': '\x1b[6~',
      'delete': '\x1b[3~',
      'backspace': '\x7f',
      // Ctrl combinations
      'ctrl+a': '\x01',
      'ctrl+b': '\x02',
      'ctrl+c': '\x03',
      'ctrl+d': '\x04',
      'ctrl+e': '\x05',
      'ctrl+f': '\x06',
      'ctrl+g': '\x07',
      'ctrl+h': '\x08',
      'ctrl+i': '\x09',
      'ctrl+j': '\x0a',
      'ctrl+k': '\x0b',
      'ctrl+l': '\x0c',
      'ctrl+m': '\x0d',
      'ctrl+n': '\x0e',
      'ctrl+o': '\x0f',
      'ctrl+p': '\x10',
      'ctrl+q': '\x11',
      'ctrl+r': '\x12',
      'ctrl+s': '\x13',
      'ctrl+t': '\x14',
      'ctrl+u': '\x15',
      'ctrl+v': '\x16',
      'ctrl+w': '\x17',
      'ctrl+x': '\x18',
      'ctrl+y': '\x19',
      'ctrl+z': '\x1a',
    };
    
    final sequence = keyMap[key.toLowerCase()];
    if (sequence != null) {
      _channel?.sink.add(sequence);
    }
  }
}
