import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = 20,
    this.color,
    this.strokeWidth,
  });

  final List<List<dynamic>> icon;
  final double size;
  final Color? color;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    return HugeIcon(
      icon: icon,
      size: size,
      color: color ?? Theme.of(context).colorScheme.onSurface,
      strokeWidth: strokeWidth,
    );
  }
}

/// Use as [InputDecoration.prefixIcon]: Material expands prefix; [HugeIcon] must be boxed.
class InputPrefixHugeIcon extends StatelessWidget {
  const InputPrefixHugeIcon(
    this.icon, {
    super.key,
    this.size = 18,
    this.color,
  });

  final List<List<dynamic>> icon;
  final double size;
  final Color? color;

  static const BoxConstraints slotConstraints = BoxConstraints(
    minWidth: 40,
    maxWidth: 40,
    minHeight: 40,
    maxHeight: 40,
  );

  /// Narrow fields (e.g. inspector toolbar search, height ~36).
  static const BoxConstraints compactSlotConstraints = BoxConstraints(
    minWidth: 32,
    maxWidth: 32,
    minHeight: 32,
    maxHeight: 32,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: HugeIcon(
            icon: icon,
            size: 24,
            color: color ?? scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
