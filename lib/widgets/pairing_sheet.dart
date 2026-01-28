import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/pairing_manager.dart';

class PairingSheet extends StatefulWidget {
  const PairingSheet({super.key});

  @override
  State<PairingSheet> createState() => _PairingSheetState();
}

class _PairingSheetState extends State<PairingSheet> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '8443');
  final _nameController = TextEditingController(text: 'My Mac');
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pairingManager = context.watch<PairingManager>();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              _buildContent(pairingManager),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(PairingManager pairingManager) {
    switch (pairingManager.state) {
      case PairingState.idle: return _buildManualEntry(pairingManager);
      case PairingState.connecting: return _buildConnecting();
      case PairingState.awaitingCode: return _buildCodeEntry(pairingManager);
      case PairingState.verifying: return _buildVerifying();
      case PairingState.paired: return _buildSuccess(pairingManager);
      case PairingState.error: return _buildError(pairingManager);
    }
  }

  Widget _buildManualEntry(PairingManager pairingManager) {
    return Column(
      children: [
        Icon(Icons.devices, size: 60, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text('Pair Your Mac', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Enter the IP address shown in the Mac app', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Device Name', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _hostController, decoration: const InputDecoration(labelText: 'IP Address', border: OutlineInputBorder()), keyboardType: TextInputType.url, autocorrect: false),
        const SizedBox(height: 12),
        TextField(controller: _portController, decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()), keyboardType: TextInputType.number),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _hostController.text.isEmpty ? null : () => pairingManager.startPairing(_hostController.text, int.tryParse(_portController.text) ?? 8443, _nameController.text),
            child: const Text('Connect'),
          ),
        ),
      ],
    );
  }

  Widget _buildConnecting() => const Column(children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Connecting...')]);
  Widget _buildVerifying() => const Column(children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Verifying...')]);

  Widget _buildCodeEntry(PairingManager pairingManager) {
    return Column(
      children: [
        Icon(Icons.lock, size: 60, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text('Enter Pairing Code', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('Enter the 6-digit code shown on ${_nameController.text}', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        SizedBox(
          width: 200,
          child: TextField(
            controller: _codeController,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8),
            maxLength: 6,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _codeController.text.length != 6 ? null : () => pairingManager.verifyPairingCode(_codeController.text, _nameController.text, _hostController.text, int.tryParse(_portController.text) ?? 8443),
            child: const Text('Verify'),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess(PairingManager pairingManager) {
    return Column(
      children: [
        Icon(Icons.check_circle, size: 60, color: Colors.green),
        const SizedBox(height: 16),
        Text('Paired!', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        FilledButton(onPressed: () { pairingManager.cancelPairing(); Navigator.pop(context); }, child: const Text('Done')),
      ],
    );
  }

  Widget _buildError(PairingManager pairingManager) {
    return Column(
      children: [
        const Icon(Icons.error, size: 60, color: Colors.red),
        const SizedBox(height: 16),
        Text('Pairing Failed', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(pairingManager.errorMessage ?? 'Unknown error', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
        const SizedBox(height: 24),
        OutlinedButton(onPressed: pairingManager.cancelPairing, child: const Text('Try Again')),
      ],
    );
  }
}
