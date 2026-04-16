import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../app_icon.dart';

/// Short lists stay natural height; long lists scroll inside [maxHeight].
class ConnectCappedScrollList extends StatefulWidget {
  const ConnectCappedScrollList({
    super.key,
    required this.maxHeight,
    required this.children,
  });

  final double maxHeight;
  final List<Widget> children;

  @override
  State<ConnectCappedScrollList> createState() =>
      _ConnectCappedScrollListState();
}

class _ConnectCappedScrollListState extends State<ConnectCappedScrollList> {
  late final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: Scrollbar(
        controller: _scroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scroll,
          primary: false,
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: widget.children,
          ),
        ),
      ),
    );
  }
}

class ConnectSectionLabel extends StatelessWidget {
  const ConnectSectionLabel({
    super.key,
    required this.text,
    required this.scheme,
  });

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

class ConnectPanel extends StatelessWidget {
  const ConnectPanel({
    super.key,
    required this.child,
    required this.scheme,
  });

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

class ConnectSelectRow extends StatelessWidget {
  const ConnectSelectRow({
    super.key,
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

class ConnectErrorBanner extends StatelessWidget {
  const ConnectErrorBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

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
