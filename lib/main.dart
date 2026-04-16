import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:macos_window_utils/macos_window_utils.dart';

import 'app_theme.dart';
import 'providers/inspector_provider.dart';
import 'providers/theme_mode_provider.dart';
import 'screens/connect_screen.dart';
import 'widgets/macos_title_bar_zoom_strip.dart';

/// Native title bar / `NSVisualEffectView` follow **macOS** appearance by default,
/// so with system dark mode the strip stays dark even when Flutter uses light
/// theme. [WindowManipulator.overrideMacOSBrightness] pins the window chrome
/// to match the effective Material brightness.
Future<void> _syncMacosTitlebarChrome({
  required ThemeMode themeMode,
  required Brightness platformBrightness,
}) async {
  if (defaultTargetPlatform != TargetPlatform.macOS) return;
  final useDark = switch (themeMode) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system => platformBrightness == Brightness.dark,
  };
  await WindowManipulator.overrideMacOSBrightness(dark: useDark);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.macOS) {
    await WindowManipulator.initialize();
    await WindowManipulator.makeTitlebarTransparent();
    await WindowManipulator.enableFullSizeContentView();
    await WindowManipulator.hideTitle();
    await WindowManipulator.setWindowBackgroundColorToClear();
  }
  final container = ProviderContainer();
  await container.read(themeModeProvider.notifier).hydrate();
  if (defaultTargetPlatform == TargetPlatform.macOS) {
    await _syncMacosTitlebarChrome(
      themeMode: container.read(themeModeProvider),
      platformBrightness:
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
  }
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const _MacosTitlebarChromeSync(child: DriftDbInspectorApp()),
    ),
  );
}

class _MacosTitlebarChromeSync extends ConsumerStatefulWidget {
  const _MacosTitlebarChromeSync({required this.child});

  final Widget child;

  @override
  ConsumerState<_MacosTitlebarChromeSync> createState() =>
      _MacosTitlebarChromeSyncState();
}

class _MacosTitlebarChromeSyncState extends ConsumerState<_MacosTitlebarChromeSync>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    _scheduleSync();
  }

  void _scheduleSync() {
    if (defaultTargetPlatform != TargetPlatform.macOS) return;
    final mode = ref.read(themeModeProvider);
    final platform =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    unawaited(_syncMacosTitlebarChrome(
      themeMode: mode,
      platformBrightness: platform,
    ));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(themeModeProvider, (_, ThemeMode _) => _scheduleSync());
    return widget.child;
  }
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
      builder: (context, child) {
        return Consumer(
          builder: (context, ref, _) {
            final title = ref.watch(macosTitleBarLabelProvider);
            return MacosTitleBarZoomWrapper(
              title: title,
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
      home: const ConnectScreen(),
    );
  }
}
