import 'package:flutter/material.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/theme_mode_provider.dart';
import 'app_icon.dart';

/// Visual treatment for where the anchor sits (connect vs top bar).
enum ThemeModeMenuStyle {
  /// Raised chip — popup opens **above** ([PopupPosition.top]).
  floating,

  /// 32×32 bar icon — popup opens **below** ([PopupPosition.bottom]).
  toolbar,
}

List<List<dynamic>> _themeModeIcon(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.light => HugeIcons.strokeRoundedSun02,
    ThemeMode.dark => HugeIcons.strokeRoundedMoon02,
    ThemeMode.system => HugeIcons.strokeRoundedComputer,
  };
}

String _themeModeLabel(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };
}

/// Theme picker using [CustomPopup] from [flutter_popup](https://pub.dev/packages/flutter_popup).
class ThemeModeMenuButton extends ConsumerWidget {
  const ThemeModeMenuButton({
    super.key,
    required this.anchorIcon,
    this.style = ThemeModeMenuStyle.floating,
  });

  final List<List<dynamic>> anchorIcon;

  final ThemeModeMenuStyle style;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final scheme = Theme.of(context).colorScheme;
    final position = style == ThemeModeMenuStyle.floating
        ? PopupPosition.top
        : PopupPosition.bottom;

    return CustomPopup(
      position: position,
      showArrow: true,
      barrierColor: Colors.black.withValues(alpha: 0.12),
      backgroundColor: scheme.surfaceContainerHigh,
      arrowColor: scheme.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      contentDecoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      content: const SizedBox(
        width: 220,
        child: _ThemeModePopupBody(),
      ),
      child: Tooltip(
        message: 'Theme',
        waitDuration: const Duration(milliseconds: 400),
        child: style == ThemeModeMenuStyle.toolbar
            ? SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: AppIcon(
                    anchorIcon,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            : Material(
                color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
                elevation: 1.5,
                shadowColor: scheme.shadow.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AppIcon(
                    anchorIcon,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ThemeModePopupBody extends ConsumerWidget {
  const _ThemeModePopupBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in ThemeMode.values)
          InkWell(
            onTap: () async {
              if (context.mounted) Navigator.of(context).pop();
              await notifier.setThemeMode(m);
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  AppIcon(
                    _themeModeIcon(m),
                    size: 18,
                    color: scheme.onSurface,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _themeModeLabel(m),
                      style: TextStyle(
                        fontWeight:
                            m == mode ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 13,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 22,
                    child: m == mode
                        ? AppIcon(
                            HugeIcons.strokeRoundedTick02,
                            size: 16,
                            color: scheme.primary,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
