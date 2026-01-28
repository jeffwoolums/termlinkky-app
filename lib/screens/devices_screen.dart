import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/pairing_manager.dart';
import '../services/connection_manager.dart';
import '../models/paired_device.dart';
import '../widgets/pairing_sheet.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  void _showPairingSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const PairingSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pairingManager = context.watch<PairingManager>();

    return Scaffold(
      appBar: AppBar(title: const Text('Devices')),
      body: pairingManager.pairedDevices.isEmpty
          ? _EmptyState(onPair: () => _showPairingSheet(context))
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'PAIRED DEVICES',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 1),
                  ),
                ),
                ...pairingManager.pairedDevices.map((device) => _DeviceTile(device: device)),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FilledButton.tonalIcon(
                    onPressed: () => _showPairingSheet(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Pair New Device'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onPair;
  const _EmptyState({required this.onPair});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.devices, size: 80, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
          const SizedBox(height: 24),
          Text('No Paired Devices', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Pair with your Mac to get started', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onPair,
            icon: const Icon(Icons.add),
            label: const Text('Pair Device'),
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final PairedDevice device;
  const _DeviceTile({required this.device});

  @override
  Widget build(BuildContext context) {
    final connectionManager = context.watch<ConnectionManager>();
    final pairingManager = context.watch<PairingManager>();
    final isConnected = connectionManager.currentDevice?.id == device.id && connectionManager.isConnected;
    final isConnecting = connectionManager.currentDevice?.id == device.id && connectionManager.state == ConnectionState.connecting;

    return Dismissible(
      key: Key(device.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => pairingManager.removePairedDevice(device),
      child: ListTile(
        leading: Icon(
          Icons.laptop_mac,
          color: isConnected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(device.name),
        subtitle: Text(device.displayAddress, style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12)),
        trailing: isConnecting
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : isConnected
                ? Icon(Icons.wifi, color: Theme.of(context).colorScheme.primary)
                : null,
        onTap: () {
          if (isConnected) {
            connectionManager.disconnect();
          } else {
            connectionManager.connect(device, pairingManager);
          }
        },
      ),
    );
  }
}
