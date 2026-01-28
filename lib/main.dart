import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/connection_manager.dart';
import 'services/pairing_manager.dart';
import 'services/settings_manager.dart';
import 'services/ai_assistant.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TermLinkyApp());
}

class TermLinkyApp extends StatelessWidget {
  const TermLinkyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PairingManager()),
        ChangeNotifierProvider(create: (_) => ConnectionManager()),
        ChangeNotifierProvider(create: (_) => SettingsManager()),
        ChangeNotifierProvider(create: (_) => AIAssistant()),
      ],
      child: MaterialApp(
        title: 'TermLinky',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF32C759),
            brightness: Brightness.dark,
          ),
          fontFamily: 'JetBrainsMono',
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF32C759),
            brightness: Brightness.dark,
          ),
        ),
        themeMode: ThemeMode.dark,
        home: const HomeScreen(),
      ),
    );
  }
}
