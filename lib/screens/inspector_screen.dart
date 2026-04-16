import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/inspector_provider.dart';
import '../widgets/inspector_data_table.dart';
import 'connect_screen.dart';

class InspectorScreen extends HookConsumerWidget {
  const InspectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspector = ref.watch(inspectorProvider);
    if (inspector == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ConnectScreen()),
          );
        }
      });
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final searchCtrl = useTextEditingController();
    final searchDebounce = useRef<Timer?>(null);

    void onSearch(String q) {
      searchDebounce.value?.cancel();
      searchDebounce.value = Timer(const Duration(milliseconds: 300), () {
        ref.read(inspectorProvider.notifier).setSearch(q);
      });
    }

    void closeInspector() {
      ref.read(inspectorProvider.notifier).close();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ConnectScreen()),
      );
    }

    final sidebarWidth = 220.0;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Column(
        children: [
          // Top bar — IDE-like
          Container(
            height: 48,
            color: scheme.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.storage_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${inspector.packageName}  ·  ${inspector.remoteDbPath.split('/').last}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (inspector.loading)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                _BarButton(
                  tooltip: 'Re-sync from device',
                  icon: Icons.sync_rounded,
                  onPressed: () =>
                      ref.read(inspectorProvider.notifier).refresh(),
                ),
                const SizedBox(width: 4),
                _BarButton(
                  tooltip: 'Close & pick another database',
                  icon: Icons.close_rounded,
                  onPressed: closeInspector,
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),

          // Error banner
          if (inspector.error != null)
            Container(
              width: double.infinity,
              color: scheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: scheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      inspector.error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Main content
          Expanded(
            child: Row(
              children: [
                // Sidebar — table list
                Container(
                  width: sidebarWidth,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    border: Border(
                      right: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                        child: Text(
                          'TABLES',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                          itemCount: inspector.tables.length,
                          itemBuilder: (_, i) {
                            final name = inspector.tables[i];
                            final selected = name == inspector.selectedTable;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Material(
                                color: selected
                                    ? scheme.primaryContainer.withValues(
                                        alpha: 0.5,
                                      )
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => ref
                                      .read(inspectorProvider.notifier)
                                      .selectTable(name),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.grid_on_rounded,
                                          size: 14,
                                          color: selected
                                              ? scheme.onPrimaryContainer
                                              : scheme.onSurfaceVariant
                                                    .withValues(alpha: 0.6),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  fontWeight: selected
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  color: selected
                                                      ? scheme
                                                            .onPrimaryContainer
                                                      : scheme.onSurface,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Data area
                Expanded(
                  child: SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Search bar
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            border: Border(
                              bottom: BorderSide(
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              if (inspector.selectedTable != null) ...[
                                Text(
                                  inspector.selectedTable!,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 16),
                              ],
                              Expanded(
                                child: SizedBox(
                                  height: 36,
                                  child: TextField(
                                    controller: searchCtrl,
                                    onChanged: onSearch,
                                    style: theme.textTheme.bodySmall,
                                    decoration: InputDecoration(
                                      hintText: 'Search rows…',
                                      prefixIcon: const Icon(
                                        Icons.search_rounded,
                                        size: 18,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: scheme.outlineVariant
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message:
                                    'Click column header to expand/collapse',
                                child: Icon(
                                  Icons.info_outline_rounded,
                                  size: 18,
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Table
                        const Expanded(child: InspectorDataTable()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        iconSize: 18,
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
