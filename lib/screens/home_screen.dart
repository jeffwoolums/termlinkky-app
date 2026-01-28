import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/pairing_manager.dart';
import '../services/ai_assistant.dart';
import 'terminal_screen.dart';
import 'ai_chat_screen.dart';
import 'devices_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _screens = const [
    TerminalScreen(),
    AIChatScreen(),
    DevicesScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pairingManager = context.read<PairingManager>();
      if (pairingManager.pairedDevices.isEmpty) {
        setState(() => _currentIndex = 2); // Devices tab
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pairingManager = context.watch<PairingManager>();
    final ai = context.watch<AIAssistant>();

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.terminal),
            label: 'Terminal',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: !ai.isConfigured,
              label: const Text('!'),
              child: const Icon(Icons.auto_awesome),
            ),
            label: 'AI',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pairingManager.pairedDevices.isEmpty,
              child: const Icon(Icons.devices),
            ),
            label: 'Devices',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
