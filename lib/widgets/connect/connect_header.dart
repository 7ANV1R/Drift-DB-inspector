import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../app_icon.dart';

/// Brand row for the top-left of the connect screen (outside the main card).
class ConnectTopBrandRow extends StatelessWidget {
  const ConnectTopBrandRow({
    super.key,
    required this.scheme,
    required this.theme,
  });

  final ColorScheme scheme;
  final ThemeData theme;

  static const _subtitle =
      'Browse SQLite from Android, the iOS Simulator, or a file on disk.';

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: scheme.primaryContainer.withValues(alpha: 0.65),
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
              const SizedBox(height: 4),
              Text(
                Platform.isMacOS
                    ? _subtitle
                    : 'Use the Mac app for devices and simulators.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
