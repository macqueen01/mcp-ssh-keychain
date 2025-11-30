import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/connection_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/transfer_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize settings provider
  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  runApp(McpFileManagerApp(settingsProvider: settingsProvider));
}

class McpFileManagerApp extends StatelessWidget {
  final SettingsProvider settingsProvider;

  const McpFileManagerApp({super.key, required this.settingsProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
        ChangeNotifierProvider.value(value: settingsProvider),
      ],
      child: MaterialApp(
        title: 'MCP File Manager',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          fontFamily: 'JetBrainsMono',
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          fontFamily: 'JetBrainsMono',
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
