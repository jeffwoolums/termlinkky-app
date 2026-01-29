import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Discovered device from network scan
class DiscoveredDevice {
  final String name;
  final String ip;
  final int port;
  final String source; // 'tailscale', 'mdns', 'manual'
  final bool isOnline;

  DiscoveredDevice({
    required this.name,
    required this.ip,
    this.port = 8443,
    required this.source,
    this.isOnline = false,
  });
}

/// Service for discovering TermLinkky servers on the network
class DeviceDiscoveryService extends ChangeNotifier {
  List<DiscoveredDevice> _devices = [];
  bool _isScanning = false;
  String? _error;

  List<DiscoveredDevice> get devices => _devices;
  bool get isScanning => _isScanning;
  String? get error => _error;

  /// Known Tailscale devices (can be loaded from settings)
  final List<Map<String, String>> _tailscaleHosts = [];

  /// Add known Tailscale hosts
  void setTailscaleHosts(List<Map<String, String>> hosts) {
    _tailscaleHosts.clear();
    _tailscaleHosts.addAll(hosts);
  }

  /// Scan for available TermLinkky servers
  Future<void> scanForDevices() async {
    _isScanning = true;
    _error = null;
    _devices = [];
    notifyListeners();

    try {
      // 1. Check known Tailscale hosts
      await _scanTailscaleHosts();
      
      // 2. Scan common local network ranges
      await _scanLocalNetwork();
      
    } catch (e) {
      _error = e.toString();
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Scan known Tailscale hosts
  Future<void> _scanTailscaleHosts() async {
    // Default known hosts (Tailscale IPs from the user's network)
    final defaultHosts = [
      {'name': 'Clawdbot Mac mini', 'ip': '100.70.5.93'},
      {'name': 'Jeff MacBook Pro', 'ip': '100.107.248.28'},
      {'name': 'RaceStream Server', 'ip': '100.93.38.46'},
      {'name': 'Orange Pi', 'ip': '100.114.87.93'},
    ];

    final hosts = _tailscaleHosts.isNotEmpty ? _tailscaleHosts : defaultHosts;

    for (final host in hosts) {
      final isOnline = await _checkHost(host['ip']!, 8443);
      _devices.add(DiscoveredDevice(
        name: host['name']!,
        ip: host['ip']!,
        port: 8443,
        source: 'tailscale',
        isOnline: isOnline,
      ));
      notifyListeners();
    }
  }

  /// Scan local network for TermLinkky servers
  Future<void> _scanLocalNetwork() async {
    // Get local IP to determine subnet
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
              // Scan common host IPs (not full range - too slow)
              await _scanSubnet(subnet, [1, 100, 101, 150, 200, 241, 242, 243]);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Local scan error: $e');
    }
  }

  /// Scan specific IPs in a subnet
  Future<void> _scanSubnet(String subnet, List<int> hosts) async {
    final futures = <Future<void>>[];
    
    for (final host in hosts) {
      final ip = '$subnet.$host';
      futures.add(_checkAndAddHost(ip));
    }
    
    await Future.wait(futures);
  }

  /// Check a single host and add if responding
  Future<void> _checkAndAddHost(String ip) async {
    final isOnline = await _checkHost(ip, 8443);
    if (isOnline) {
      // Check if already in list
      if (!_devices.any((d) => d.ip == ip)) {
        _devices.add(DiscoveredDevice(
          name: 'Device at $ip',
          ip: ip,
          port: 8443,
          source: 'local',
          isOnline: true,
        ));
        notifyListeners();
      }
    }
  }

  /// Check if a host is responding on the given port
  Future<bool> _checkHost(String ip, int port) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 1500),
      );
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Quick check a single device
  Future<bool> checkDevice(String ip, int port) async {
    return _checkHost(ip, port);
  }
}
