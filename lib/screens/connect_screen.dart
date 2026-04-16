import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;

import '../providers/adb_provider.dart';
import '../providers/inspector_provider.dart';
import '../widgets/app_icon.dart';
import 'inspector_screen.dart';

class ConnectScreen extends HookConsumerWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final devicesAsync = ref.watch(devicesProvider);
    final devicesRefreshing = ref.watch(devicesRefreshingProvider);
    final discoveryAsync = ref.watch(discoveryProvider);
    final spinDevices = useAnimationController(
      duration: const Duration(seconds: 1),
    );
    useEffect(() {
      if (devicesRefreshing) {
        spinDevices.repeat();
      } else {
        spinDevices
          ..stop()
          ..reset();
      }
      return null;
    }, [devicesRefreshing]);

    final packageCtrl = useTextEditingController();
    final selectedSerial = useState<String?>(null);
    final selectedDb = useState<String?>(null);
    final pulling = useState(false);
    final error = useState<String?>(null);

    final dbPaths = discoveryAsync.value?.paths ?? [];
    final discoveryLog = discoveryAsync.value?.log ?? '';
    final discovering = discoveryAsync.isLoading;

    Future<void> discover() async {
      final serial = selectedSerial.value;
      final pkg = packageCtrl.text.trim();
      if (serial == null || pkg.isEmpty) {
        error.value = 'Pick a device and enter application ID.';
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
        error.value = e.toString().replaceFirst('AdbException: ', '');
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
        error.value = e.toString().replaceFirst('AdbException: ', '');
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: scheme.primaryContainer.withValues(
                              alpha: 0.65,
                            ),
                          ),
                          child: AppIcon(
                            HugeIcons.strokeRoundedDatabase,
                            color: scheme.onPrimaryContainer,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Drift DB Inspector',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              Text(
                                'ADB · debuggable app · local copy',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    if (error.value != null) ...[
                      _ErrorBanner(
                        message: error.value!,
                        onDismiss: () => error.value = null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    _SectionLabel(text: 'Device', scheme: scheme),
                    const SizedBox(height: 8),
                    devicesAsync.when(
                      data: (devices) {
                        final ready = devices.where((d) => d.isReady).toList();
                        if (selectedSerial.value == null && ready.length == 1) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            selectedSerial.value = ready.first.serial;
                          });
                        }
                        if (ready.isEmpty) {
                          return Text(
                            'No device in "device" state. Plug in or start emulator.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          );
                        }
                        return _Panel(
                          scheme: scheme,
                          child: Column(
                            children: ready.map((d) {
                              final sel = selectedSerial.value == d.serial;
                              return _SelectRow(
                                selected: sel,
                                onTap: () => selectedSerial.value = d.serial,
                                child: Row(
                                  children: [
                                    AppIcon(
                                      HugeIcons.strokeRoundedAndroid,
                                      size: 20,
                                      color: sel
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            d.model ?? d.serial,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: sel
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                ),
                                          ),
                                          Text(
                                            d.serial,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                  fontFamily: 'monospace',
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (sel)
                                      AppIcon(
                                        HugeIcons.strokeRoundedCheckmarkCircle02,
                                        size: 20,
                                        color: scheme.primary,
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                      loading: () => const LinearProgressIndicator(
                        minHeight: 3,
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                      error: (e, _) => Text(
                        'Devices: $e',
                        style: TextStyle(color: scheme.error, fontSize: 13),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () =>
                            ref.read(devicesProvider.notifier).refresh(),
                        icon: RotationTransition(
                          turns: spinDevices,
                          child: AppIcon(
                            HugeIcons.strokeRoundedRefresh,
                            size: 18,
                            color: scheme.primary,
                          ),
                        ),
                        label: const Text('Refresh devices'),
                      ),
                    ),

                    _SectionLabel(text: 'Application ID', scheme: scheme),
                    const SizedBox(height: 8),
                    TextField(
                      controller: packageCtrl,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'com.company.app',
                        prefixIconConstraints:
                            InputPrefixHugeIcon.slotConstraints,
                        prefixIcon: InputPrefixHugeIcon(
                          HugeIcons.strokeRoundedPackage,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.35,
                        ),
                      ),
                      onSubmitted: (_) => discover(),
                    ),
                    const SizedBox(height: 20),

                    FilledButton.icon(
                      onPressed: discovering ? null : discover,
                      icon: discovering
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onPrimary,
                              ),
                            )
                          : AppIcon(
                              HugeIcons.strokeRoundedCompass,
                              size: 20,
                              color: scheme.onPrimary,
                            ),
                      label: Text(
                        discovering ? 'Scanning…' : 'Discover databases',
                      ),
                    ),

                    if (dbPaths.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _SectionLabel(
                        text: 'Database file (${dbPaths.length})',
                        scheme: scheme,
                      ),
                      const SizedBox(height: 8),
                      _Panel(
                        scheme: scheme,
                        child: Column(
                          children: dbPaths.map((path) {
                            final sel = selectedDb.value == path;
                            final name = p.basename(path);
                            final parent = p.dirname(path);
                            return _SelectRow(
                              selected: sel,
                              onTap: () => selectedDb.value = path,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppIcon(
                                    HugeIcons.strokeRoundedFile01,
                                    size: 20,
                                    color: sel
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: sel
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                                fontFamily: 'monospace',
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          parent,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                                fontFamily: 'monospace',
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (sel)
                                    AppIcon(
                                      HugeIcons.strokeRoundedCheckmarkCircle02,
                                      size: 20,
                                      color: scheme.primary,
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: (pulling.value || selectedDb.value == null)
                            ? null
                            : pullAndOpen,
                        icon: pulling.value
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.primary,
                                ),
                              )
                            : AppIcon(
                                HugeIcons.strokeRoundedDownload01,
                                size: 20,
                                color: scheme.primary,
                              ),
                        label: const Text('Pull & inspect'),
                      ),
                    ],

                    if (discoveryLog.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: Text(
                          'Discovery log',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        children: [
                          Container(
                            height: 180,
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest.withValues(
                                alpha: 0.4,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                discoveryLog,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10.5,
                                  height: 1.35,
                                  color: scheme.onSurface,
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
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.scheme});

  final String text;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, required this.scheme});

  final Widget child;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(6), child: child),
    );
  }
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.45)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(
              HugeIcons.strokeRoundedAlertCircle,
              color: scheme.onErrorContainer,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SelectableText(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onErrorContainer,
                  height: 1.35,
                ),
              ),
            ),
            IconButton(
              iconSize: 20,
              onPressed: onDismiss,
              icon: AppIcon(
                HugeIcons.strokeRoundedCancel01,
                color: scheme.onErrorContainer,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
