import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../models/connect_backend.dart';
import '../../models/device.dart';
import '../../models/simulator_device.dart';
import '../../providers/adb_provider.dart';
import '../../providers/inspector_provider.dart';
import '../../providers/simulator_provider.dart';
import '../app_icon.dart';
import 'connect_primitives.dart';

/// Device / simulator listing, package field, discovery, DB pick, pull, log.
class ConnectRemoteFlow extends ConsumerWidget {
  const ConnectRemoteFlow({
    super.key,
    required this.backend,
    required this.packageCtrl,
    required this.selectedSerial,
    required this.onSerialChanged,
    required this.selectedDb,
    required this.onDbChanged,
    required this.spinController,
    required this.pulling,
    required this.onDiscover,
    required this.onPullAndOpen,
  });

  final ConnectBackend backend;
  final TextEditingController packageCtrl;
  final String? selectedSerial;
  final ValueChanged<String?> onSerialChanged;
  final String? selectedDb;
  final ValueChanged<String?> onDbChanged;
  final AnimationController spinController;
  final bool pulling;
  final VoidCallback onDiscover;
  final VoidCallback onPullAndOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final devicesAsync = ref.watch(devicesProvider);
    final simulatorsAsync = ref.watch(simulatorsProvider);
    final discoveryAsync = ref.watch(discoveryProvider);
    final dbPaths = discoveryAsync.value?.paths ?? [];
    final discoveryLog = discoveryAsync.value?.log ?? '';
    final discovering = discoveryAsync.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConnectSectionLabel(
          text: backend == ConnectBackend.adb ? 'Device' : 'Simulator',
          scheme: scheme,
        ),
        const SizedBox(height: 8),
        if (backend == ConnectBackend.adb)
          devicesAsync.when(
            data: (List<AdbDevice> devices) {
              final ready = devices.where((d) => d.isReady).toList();
              if (selectedSerial == null && ready.length == 1) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onSerialChanged(ready.first.serial);
                });
              }
              if (ready.isEmpty) {
                return Text(
                  Platform.isIOS || Platform.isAndroid
                      ? 'Android listing runs on macOS with adb installed.'
                      : 'No device in "device" state. Plug in USB or start an emulator.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                );
              }
              return ConnectPanel(
                scheme: scheme,
                child: ConnectCappedScrollList(
                  maxHeight: 280,
                  children: ready.map((d) {
                    final sel = selectedSerial == d.serial;
                    return ConnectSelectRow(
                      selected: sel,
                      onTap: () => onSerialChanged(d.serial),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.model ?? d.serial,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: sel
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  d.serial,
                                  style: theme.textTheme.labelSmall?.copyWith(
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
          )
        else
          simulatorsAsync.when(
            data: (List<IosSimulatorDevice> sims) {
              if (selectedSerial == null) {
                final booted = sims.where((d) => d.isBooted).toList();
                if (booted.length == 1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onSerialChanged(booted.first.udid);
                  });
                } else if (sims.length == 1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onSerialChanged(sims.first.udid);
                  });
                }
              }
              if (sims.isEmpty) {
                return Text(
                  'No simulators. Open Simulator or Xcode → Devices.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                );
              }
              return ConnectPanel(
                scheme: scheme,
                child: ConnectCappedScrollList(
                  maxHeight: 280,
                  children: sims.map((d) {
                    final sel = selectedSerial == d.udid;
                    return ConnectSelectRow(
                      selected: sel,
                      onTap: () => onSerialChanged(d.udid),
                      child: Row(
                        children: [
                          AppIcon(
                            HugeIcons.strokeRoundedApple,
                            size: 20,
                            color: sel
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.displayTitle,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: sel
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${d.runtimeShort} · ${d.udid}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
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
              );
            },
            loading: () => const LinearProgressIndicator(
              minHeight: 3,
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
            error: (e, _) => Text(
              'Simulators: $e',
              style: TextStyle(color: scheme.error, fontSize: 13),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              if (backend == ConnectBackend.adb) {
                ref.read(devicesProvider.notifier).refresh();
              } else {
                ref.read(simulatorsProvider.notifier).refresh();
              }
            },
            icon: RotationTransition(
              turns: spinController,
              child: AppIcon(
                HugeIcons.strokeRoundedRefresh,
                size: 18,
                color: scheme.primary,
              ),
            ),
            label: Text(
              backend == ConnectBackend.adb
                  ? 'Refresh devices'
                  : 'Refresh simulators',
            ),
          ),
        ),
        ConnectSectionLabel(
          text: backend == ConnectBackend.adb ? 'Application ID' : 'Bundle ID',
          scheme: scheme,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: packageCtrl,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: 'com.company.app',
            prefixIconConstraints: InputPrefixHugeIcon.slotConstraints,
            prefixIcon: InputPrefixHugeIcon(
              HugeIcons.strokeRoundedPackage,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          ),
          onSubmitted: (_) => onDiscover(),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: discovering ? null : onDiscover,
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
            discovering
                ? 'Scanning…'
                : (backend == ConnectBackend.adb
                    ? 'Discover databases'
                    : 'Find database files'),
          ),
        ),
        if (dbPaths.isNotEmpty) ...[
          const SizedBox(height: 24),
          ConnectSectionLabel(
            text: 'Database file (${dbPaths.length})',
            scheme: scheme,
          ),
          const SizedBox(height: 8),
          ConnectPanel(
            scheme: scheme,
            child: Column(
              children: dbPaths.map((path) {
                final sel = selectedDb == path;
                final name = p.basename(path);
                final parent = p.dirname(path);
                return ConnectSelectRow(
                  selected: sel,
                  onTap: () => onDbChanged(path),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppIcon(
                        HugeIcons.strokeRoundedFile01,
                        size: 20,
                        color: sel ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.bodyMedium?.copyWith(
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
                              style: theme.textTheme.labelSmall?.copyWith(
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
            onPressed: (pulling || selectedDb == null) ? null : onPullAndOpen,
            icon: pulling
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
            label: Text(
              backend == ConnectBackend.adb ? 'Pull & inspect' : 'Copy & inspect',
            ),
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
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
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
    );
  }
}
