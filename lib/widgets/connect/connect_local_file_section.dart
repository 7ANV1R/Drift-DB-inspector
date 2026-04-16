import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../app_icon.dart';
import 'connect_primitives.dart';

class ConnectLocalFileSection extends StatelessWidget {
  const ConnectLocalFileSection({
    super.key,
    required this.scheme,
    required this.pulling,
    required this.pickingFile,
    required this.onPickFile,
  });

  final ColorScheme scheme;
  final bool pulling;

  /// True while the native file dialog is being prepared or shown.
  final bool pickingFile;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = pulling || pickingFile;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConnectSectionLabel(text: 'SQLite file', scheme: scheme),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                HugeIcons.strokeRoundedFileImport,
                size: 40,
                color: scheme.primary.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 14),
              Text(
                'Drop a .db or .sqlite file here',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'or choose from disk',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: busy ? null : onPickFile,
                icon: busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      )
                    : AppIcon(
                        HugeIcons.strokeRoundedFile01,
                        size: 18,
                        color: scheme.primary,
                      ),
                label: Text(
                  pulling
                      ? 'Opening database…'
                      : pickingFile
                          ? 'Choosing file…'
                          : 'Choose file…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
