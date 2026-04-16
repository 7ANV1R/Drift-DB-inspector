import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DriftDbInspectorApp());
}

class DriftDbInspectorApp extends StatelessWidget {
  const DriftDbInspectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drift DB Inspector',
      theme: buildAppTheme(brightness: Brightness.light),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
