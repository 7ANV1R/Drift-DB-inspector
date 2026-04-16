import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../models/connect_backend.dart';
import '../app_icon.dart';
import 'connect_helpers.dart';

class ConnectHeader extends StatelessWidget {
  const ConnectHeader({
    super.key,
    required this.backend,
    required this.scheme,
    required this.theme,
  });

  final ConnectBackend backend;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
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
              Text(
                Platform.isMacOS
                    ? connectSubtitle(backend)
                    : 'Use the Mac app for devices and simulators.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
