import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/pairing_manager.dart';
import '../services/ai_assistant.dart';
import '../services/connection_manager.dart';
import 'terminal_screen.dart';
import 'ai_chat_screen.dart';
import 'ai_sessions_screen.dart';
import 'devices_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pairingManager = context.read<PairingManager>();
      if (pairingManager.pairedDevices.isEmpty) {
        setState(() => _currentIndex = 3); // Devices tab
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pairingManager = context.watch<PairingManager>();
    final ai = context.watch<AIAssistant>();
    final connection = context.watch<ConnectionManager>();

    final screens = [
      const TerminalScreen(),
      const AIChatScreen(),       // Mode 1: AI on phone
      const AISessionsScreen(),    // Mode 2: AI on server
      const DevicesScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: !connection.isConnected,
              backgroundColor: Colors.orange,
              label: const Text('!'),
              child: const Icon(Icons.terminal),
            ),
            label: 'Terminal',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: !ai.isConfigured,
              label: const Text('!'),
              child: const Icon(Icons.phone_android_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: !ai.isConfigured,
              label: const Text('!'),
              child: const Icon(Icons.phone_android),
            ),
            label: 'Local AI',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: connection.isConnected,
              backgroundColor: Colors.green,
              child: const Icon(Icons.computer_outlined),
            ),
            selectedIcon: const Icon(Icons.computer),
            label: 'Server AI',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pairingManager.pairedDevices.isEmpty,
              child: const Icon(Icons.devices_outlined),
            ),
            selectedIcon: const Icon(Icons.devices),
            label: 'Devices',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
