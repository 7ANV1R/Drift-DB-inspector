import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;

import '../models/connect_backend.dart';
import '../providers/adb_provider.dart';
import '../providers/inspector_provider.dart';
import '../providers/simulator_provider.dart';
import '../widgets/app_icon.dart';
import '../widgets/connect/connect_backend_selector.dart';
import '../widgets/connect/connect_header.dart';
import '../widgets/connect/connect_helpers.dart';
import '../widgets/connect/connect_how_it_works.dart';
import '../widgets/connect/connect_local_file_section.dart';
import '../widgets/connect/connect_primitives.dart';
import '../widgets/connect/connect_remote_flow.dart';
import '../widgets/theme_mode_menu_button.dart';
import 'inspector_screen.dart';

class ConnectScreen extends HookConsumerWidget {
  const ConnectScreen({super.key});

  static bool get _dropTargetSupported =>
      !kIsWeb &&
      (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final backend = useState(ConnectBackend.adb);
    final dragHover = useState(false);
    final devicesRefreshing = ref.watch(devicesRefreshingProvider);
    final simulatorsRefreshing = ref.watch(simulatorsRefreshingProvider);
    final listRefreshing = switch (backend.value) {
      ConnectBackend.adb => devicesRefreshing,
      ConnectBackend.iosSimulator => simulatorsRefreshing,
      ConnectBackend.localFile => false,
    };
    final spinDevices = useAnimationController(
      duration: const Duration(seconds: 1),
    );
    useEffect(() {
      if (listRefreshing) {
        spinDevices.repeat();
      } else {
        spinDevices
          ..stop()
          ..reset();
      }
      return null;
    }, [listRefreshing]);

    final packageCtrl = useTextEditingController();
    final selectedSerial = useState<String?>(null);
    final selectedDb = useState<String?>(null);
    final pulling = useState(false);
    final pickingFile = useState(false);
    final error = useState<String?>(null);

    Future<void> openLocalDatabasePath(String path) async {
      if (!pathLooksLikeSqlite(path)) {
        error.value =
            'Not a supported SQLite file (.db, .sqlite, or .sqlite3).';
        return;
      }
      pulling.value = true;
      error.value = null;
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!context.mounted) return;
      try {
        await ref.read(inspectorProvider.notifier).openDatabase(
              backend: ConnectBackend.localFile,
              serial: 'local',
              packageName: p.basename(path),
              remoteDbPath: path,
            );
        if (!context.mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const InspectorScreen()),
        );
      } catch (e) {
        error.value = formatConnectError(e);
      } finally {
        pulling.value = false;
      }
    }

    Future<void> discover() async {
      if (backend.value == ConnectBackend.localFile) return;
      final serial = selectedSerial.value;
      final pkg = packageCtrl.text.trim();
      if (serial == null || pkg.isEmpty) {
        error.value = backend.value == ConnectBackend.adb
            ? 'Pick a device and enter application ID.'
            : 'Pick a simulator and enter bundle ID.';
        return;
      }
      error.value = null;
      selectedDb.value = null;
      try {
        final result = await ref
            .read(discoveryProvider.notifier)
            .discover(backend.value, serial, pkg);
        if (result.paths.length == 1) {
          selectedDb.value = result.paths.first;
        }
      } catch (e) {
        error.value = formatConnectError(e);
      }
    }

    Future<void> pullAndOpen() async {
      final serial = selectedSerial.value;
      final pkg = packageCtrl.text.trim();
      final db = selectedDb.value;
      if (serial == null || pkg.isEmpty || db == null) return;

      pulling.value = true;
      error.value = null;
      try {
        await ref.read(inspectorProvider.notifier).openDatabase(
              backend: backend.value,
              serial: serial,
              packageName: pkg,
              remoteDbPath: db,
            );
        if (!context.mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const InspectorScreen()),
        );
      } catch (e) {
        error.value = formatConnectError(e);
      } finally {
        pulling.value = false;
      }
    }

    Future<void> pickLocalSqlite() async {
      if (pulling.value || pickingFile.value) return;
      pickingFile.value = true;
      error.value = null;
      try {
        // Paint loader + finish button splash before native code runs.
        await WidgetsBinding.instance.endOfFrame;
        await Future<void>.delayed(const Duration(milliseconds: 48));
        if (!context.mounted) return;

        final r = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['db', 'sqlite', 'sqlite3'],
          dialogTitle: 'Choose a SQLite database',
        );
        if (!context.mounted) return;
        if (r == null || r.files.isEmpty) return;
        final path = r.files.single.path;
        if (path == null) return;

        pickingFile.value = false;
        await openLocalDatabasePath(path);
      } finally {
        if (context.mounted) pickingFile.value = false;
      }
    }

    void onDropDone(DropDoneDetails details) {
      if (details.files.isEmpty) return;
      final path = details.files.first.path;
      if (path.isEmpty) {
        error.value =
            'Could not read that file from the drop. Try Choose file instead.';
        return;
      }
      unawaited(openLocalDatabasePath(path));
    }

    final cardContent = Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error.value != null) ...[
            ConnectErrorBanner(
              message: error.value!,
              onDismiss: () => error.value = null,
            ),
            const SizedBox(height: 16),
          ],
          ConnectBackendSelector(
            backend: backend.value,
            scheme: scheme,
            onBackendChanged: (b) => backend.value = b,
            onClearSelection: () {
              selectedSerial.value = null;
              selectedDb.value = null;
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: backend.value == ConnectBackend.localFile
                ? KeyedSubtree(
                    key: const ValueKey<String>('tab_local'),
                    child: ConnectLocalFileSection(
                      scheme: scheme,
                      pulling: pulling.value,
                      pickingFile: pickingFile.value,
                      onPickFile: () => unawaited(pickLocalSqlite()),
                    ),
                  )
                : KeyedSubtree(
                    key: ValueKey<String>(
                      backend.value == ConnectBackend.adb
                          ? 'tab_android'
                          : 'tab_ios',
                    ),
                    child: ConnectRemoteFlow(
                      backend: backend.value,
                      packageCtrl: packageCtrl,
                      selectedSerial: selectedSerial.value,
                      onSerialChanged: (s) => selectedSerial.value = s,
                      selectedDb: selectedDb.value,
                      onDbChanged: (p) => selectedDb.value = p,
                      spinController: spinDevices,
                      pulling: pulling.value,
                      onDiscover: discover,
                      onPullAndOpen: pullAndOpen,
                    ),
                  ),
          ),
        ],
      ),
    );

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dragHover.value
              ? scheme.primary.withValues(alpha: 0.55)
              : scheme.outlineVariant.withValues(alpha: 0.45),
          width: dragHover.value ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: cardContent,
    );

    final fileUiBusy = pulling.value || pickingFile.value;

    final scrollChild = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: _dropTargetSupported
          ? DropTarget(
              enable: _dropTargetSupported && !fileUiBusy,
              onDragEntered: (_) => dragHover.value = true,
              onDragExited: (_) => dragHover.value = false,
              onDragDone: (d) {
                dragHover.value = false;
                onDropDone(d);
              },
              child: card,
            )
          : card,
    );

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 24, 8),
                  child: ConnectTopBrandRow(
                    scheme: scheme,
                    theme: theme,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                    child: scrollChild,
                  ),
                ),
              ),
            ],
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ThemeModeMenuButton(
                      anchorIcon: HugeIcons.strokeRoundedPaintBoard,
                      style: ThemeModeMenuStyle.floating,
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'How it works',
                      waitDuration: const Duration(milliseconds: 400),
                      child: Material(
                        color: scheme.surfaceContainerHigh
                            .withValues(alpha: 0.92),
                        elevation: 1.5,
                        shadowColor: scheme.shadow.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => showConnectHowItWorks(context),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: AppIcon(
                              HugeIcons.strokeRoundedInformationCircle,
                              size: 20,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
