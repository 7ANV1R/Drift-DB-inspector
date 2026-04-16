import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/connect_backend.dart';
import '../../providers/inspector_provider.dart';
import '../app_icon.dart';

class ConnectBackendSelector extends ConsumerWidget {
  const ConnectBackendSelector({
    super.key,
    required this.backend,
    required this.onBackendChanged,
    required this.onClearSelection,
    required this.scheme,
  });

  final ConnectBackend backend;
  final ValueChanged<ConnectBackend> onBackendChanged;
  final VoidCallback onClearSelection;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isMacOS) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ConnectBackend>(
          segments: [
            ButtonSegment<ConnectBackend>(
              value: ConnectBackend.adb,
              label: const Text('Android'),
              icon: AppIcon(
                HugeIcons.strokeRoundedAndroid,
                size: 16,
                color: scheme.onSurface,
              ),
            ),
            ButtonSegment<ConnectBackend>(
              value: ConnectBackend.iosSimulator,
              label: const Text('iOS Simulator'),
              icon: AppIcon(
                HugeIcons.strokeRoundedApple,
                size: 16,
                color: scheme.onSurface,
              ),
            ),
            ButtonSegment<ConnectBackend>(
              value: ConnectBackend.localFile,
              label: const Text('Open file'),
              icon: AppIcon(
                HugeIcons.strokeRoundedFile01,
                size: 16,
                color: scheme.onSurface,
              ),
            ),
          ],
          selected: {backend},
          onSelectionChanged: (s) {
            onBackendChanged(s.first);
            onClearSelection();
            ref.invalidate(discoveryProvider);
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
