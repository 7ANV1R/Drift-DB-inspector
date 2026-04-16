import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/device.dart';
import '../providers/adb_provider.dart';
import '../providers/inspector_provider.dart';
import 'inspector_screen.dart';

class ConnectScreen extends HookConsumerWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final devicesAsync = ref.watch(devicesProvider);
    final discoveryAsync = ref.watch(discoveryProvider);

    final packageCtrl = useTextEditingController();
    final selectedSerial = useState<String?>(null);
    final selectedDb = useState<String?>(null);
    final pulling = useState(false);
    final error = useState<String?>(null);

    final dbPaths = discoveryAsync.value?.paths ?? [];
    final discoveryLog = discoveryAsync.value?.log ?? '';

    Future<void> discover() async {
      final serial = selectedSerial.value;
      final pkg = packageCtrl.text.trim();
      if (serial == null || pkg.isEmpty) {
        error.value = 'Select a device and enter application ID.';
        return;
      }
      error.value = null;
      selectedDb.value = null;
      try {
        final result = await ref
            .read(discoveryProvider.notifier)
            .discover(serial, pkg);
        if (result.paths.length == 1) {
          selectedDb.value = result.paths.first;
        }
      } catch (e) {
        error.value = e.toString();
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
        await ref
            .read(inspectorProvider.notifier)
            .openDatabase(serial: serial, packageName: pkg, remoteDbPath: db);
        if (!context.mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const InspectorScreen()),
        );
      } catch (e) {
        error.value = e.toString();
      } finally {
        pulling.value = false;
      }
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary,
                            Color.lerp(scheme.primary, scheme.tertiary, 0.5)!,
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.storage_rounded,
                        color: scheme.onPrimary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Drift DB Inspector',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Connect to inspect your database',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                if (error.value != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: scheme.onErrorContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SelectableText(
                            error.value!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onErrorContainer,
                            ),
                          ),
                        ),
                        IconButton(
                          iconSize: 18,
                          onPressed: () => error.value = null,
                          icon: Icon(
                            Icons.close,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Device
                Text(
                  'Device',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: devicesAsync.when(
                        data: (devices) {
                          final ready = devices
                              .where((d) => d.isReady)
                              .toList();
                          if (selectedSerial.value == null &&
                              ready.length == 1) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              selectedSerial.value = ready.first.serial;
                            });
                          }
                          return InputDecorator(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(
                                Icons.smartphone_outlined,
                                size: 20,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                isDense: true,
                                borderRadius: BorderRadius.circular(12),
                                value: _validSerial(
                                  selectedSerial.value,
                                  ready,
                                ),
                                hint: Text(
                                  ready.isEmpty
                                      ? 'No devices found'
                                      : 'Choose device',
                                ),
                                items: ready
                                    .map(
                                      (d) => DropdownMenuItem(
                                        value: d.serial,
                                        child: Text(
                                          d.displayLabel,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => selectedSerial.value = v,
                              ),
                            ),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text(
                          'Error: $e',
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Refresh devices',
                      onPressed: () =>
                          ref.read(devicesProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Package
                Text(
                  'Application ID',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: packageCtrl,
                  decoration: const InputDecoration(
                    hintText: 'com.company.app',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                  onSubmitted: (_) => discover(),
                ),
                const SizedBox(height: 20),

                FilledButton.icon(
                  onPressed: discoveryAsync.isLoading ? null : () => discover(),
                  icon: discoveryAsync.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.travel_explore_rounded),
                  label: const Text('Discover databases'),
                ),
                const SizedBox(height: 20),

                if (dbPaths.isNotEmpty) ...[
                  Text(
                    'Database file',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(
                        Icons.insert_drive_file_outlined,
                        size: 20,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        isDense: true,
                        borderRadius: BorderRadius.circular(12),
                        value: dbPaths.contains(selectedDb.value)
                            ? selectedDb.value
                            : null,
                        hint: const Text('Pick a database'),
                        items: dbPaths
                            .map(
                              (path) => DropdownMenuItem(
                                value: path,
                                child: Text(
                                  path,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => selectedDb.value = v,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: (pulling.value || selectedDb.value == null)
                        ? null
                        : pullAndOpen,
                    icon: pulling.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.downloading_rounded),
                    label: const Text('Pull & inspect'),
                  ),
                ],

                if (discoveryLog.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Discovery log',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    children: [
                      Container(
                        height: 200,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            discoveryLog,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validSerial(String? serial, List<AdbDevice> ready) {
    if (serial == null) return null;
    return ready.any((d) => d.serial == serial) ? serial : null;
  }
}
