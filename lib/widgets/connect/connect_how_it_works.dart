import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../app_icon.dart';

/// Opens a readable “how it works” sheet (Android / Simulator / file).
void showConnectHowItWorks(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final theme = Theme.of(context);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How it works',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _HowSection(
                  scheme: scheme,
                  theme: theme,
                  icon: HugeIcons.strokeRoundedAndroid,
                  title: 'Android',
                  body:
                      'Start an emulator or plug in a device with USB debugging. '
                      'Choose it in the list, enter the app’s package name (application ID), '
                      'then tap Discover to find SQLite files inside that app. '
                      'Pick a file and use Pull & inspect to copy it here and open it.',
                ),
                const SizedBox(height: 18),
                _HowSection(
                  scheme: scheme,
                  theme: theme,
                  icon: HugeIcons.strokeRoundedApple,
                  title: 'iOS Simulator',
                  body:
                      'Boot a simulator (e.g. from Xcode). Select it, enter the app’s bundle ID, '
                      'then Discover to list databases. Copy & inspect pulls the file from the '
                      'simulator onto this Mac so you can browse it.',
                ),
                const SizedBox(height: 18),
                _HowSection(
                  scheme: scheme,
                  theme: theme,
                  icon: HugeIcons.strokeRoundedFile01,
                  title: 'Open file',
                  body:
                      'Use Choose file or drag a .db / .sqlite file onto the card. '
                      'The database is opened read-only from disk—nothing is uploaded.',
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _HowSection extends StatelessWidget {
  const _HowSection({
    required this.scheme,
    required this.theme,
    required this.icon,
    required this.title,
    required this.body,
  });

  final ColorScheme scheme;
  final ThemeData theme;
  final List<List<dynamic>> icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: AppIcon(icon, size: 22, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
