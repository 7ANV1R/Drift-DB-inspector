import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;

import '../models/connect_backend.dart';
import '../providers/adb_provider.dart';
import '../providers/inspector_provider.dart';
import '../providers/simulator_provider.dart';
import '../widgets/connect/connect_backend_selector.dart';
import '../widgets/connect/connect_header.dart';
import '../widgets/connect/connect_helpers.dart';
import '../widgets/connect/connect_local_file_section.dart';
import '../widgets/connect/connect_primitives.dart';
import '../widgets/connect/connect_remote_flow.dart';
import 'inspector_screen.dart';

class ConnectScreen extends HookConsumerWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final backend = useState(ConnectBackend.adb);
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
    final error = useState<String?>(null);

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
      error.value = null;
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['db', 'sqlite', 'sqlite3'],
        dialogTitle: 'Choose a SQLite database',
      );
      if (r == null || r.files.isEmpty) return;
      final path = r.files.single.path;
      if (path == null) return;
      if (!pathLooksLikeSqlite(path)) {
        error.value = 'Pick a file ending in .db, .sqlite, or .sqlite3';
        return;
      }

      pulling.value = true;
      error.value = null;
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

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConnectHeader(
                      backend: backend.value,
                      scheme: scheme,
                      theme: theme,
                    ),
                    const SizedBox(height: 28),
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
                    if (backend.value != ConnectBackend.localFile)
                      ConnectRemoteFlow(
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
                      )
                    else
                      ConnectLocalFileSection(
                        scheme: scheme,
                        pulling: pulling.value,
                        onPickFile: pickLocalSqlite,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
