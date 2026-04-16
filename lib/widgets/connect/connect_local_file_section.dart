import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../app_icon.dart';
import 'connect_primitives.dart';

class ConnectLocalFileSection extends StatelessWidget {
  const ConnectLocalFileSection({
    super.key,
    required this.scheme,
    required this.pulling,
    required this.onPickFile,
  });

  final ColorScheme scheme;
  final bool pulling;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConnectSectionLabel(text: 'SQLite file', scheme: scheme),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: pulling ? null : onPickFile,
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
                  HugeIcons.strokeRoundedFile01,
                  size: 18,
                  color: scheme.primary,
                ),
          label: Text(pulling ? 'Opening…' : 'Choose file…'),
        ),
      ],
    );
  }
}
