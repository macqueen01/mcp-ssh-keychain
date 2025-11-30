import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/connection_provider.dart';
import 'providers/transfer_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const McpFileManagerApp());
}

class McpFileManagerApp extends StatelessWidget {
  const McpFileManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
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
