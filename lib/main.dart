import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'app_theme.dart';
import 'providers/theme_mode_provider.dart';
import 'screens/connect_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await container.read(themeModeProvider.notifier).hydrate();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DriftDbInspectorApp(),
    ),
  );
}

class DriftDbInspectorApp extends ConsumerWidget {
  const DriftDbInspectorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Drift DB Inspector',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness: Brightness.light),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      themeMode: themeMode,
      home: const ConnectScreen(),
    );
  }
}
