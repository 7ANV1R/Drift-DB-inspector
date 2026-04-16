import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/table_info.dart';
import '../providers/inspector_provider.dart';
import 'app_icon.dart';

class InspectorDataTable extends HookConsumerWidget {
  const InspectorDataTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspector = ref.watch(inspectorProvider);
    if (inspector == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final columns = inspector.columns;
    final rows = inspector.rows;
    final totalRows = inspector.totalRows;
    final page = inspector.page;
    const pageSize = InspectorState.pageSize;
    final lastPage = totalRows == 0 ? 0 : (totalRows / pageSize).ceil() - 1;
    final start = totalRows == 0 ? 0 : page * pageSize + 1;
    final end = ((page + 1) * pageSize).clamp(0, totalRows);

    final expandedCols = useState<Set<String>>({});
    final hCtrl = useScrollController();
    final vCtrl = useScrollController();

    if (columns.isEmpty) {
      return Center(
        child: Text(
          'Select a table',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 0.3,
      color: scheme.onPrimaryContainer,
    );

    final cellStyle = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.35,
      color: scheme.onSurface,
    );

    final nullStyle = cellStyle?.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
      fontStyle: FontStyle.italic,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Scrollbar(
            controller: hCtrl,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: hCtrl,
              scrollDirection: Axis.horizontal,
              child: Scrollbar(
                controller: vCtrl,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: vCtrl,
                  scrollDirection: Axis.vertical,
                  child: _buildTable(
                    context,
                    columns: columns,
                    rows: rows,
                    expandedCols: expandedCols,
                    scheme: scheme,
                    headerStyle: headerStyle,
                    cellStyle: cellStyle,
                    nullStyle: nullStyle,
                  ),
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text(
                totalRows == 0 ? 'No rows' : '$start–$end of $totalRows rows',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              _PageButton(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                onPressed: page > 0 && !inspector.loading
                    ? () => ref.read(inspectorProvider.notifier).prevPage()
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  totalRows == 0 ? '—' : '${page + 1} / ${lastPage + 1}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _PageButton(
                icon: HugeIcons.strokeRoundedArrowRight01,
                onPressed: page < lastPage && !inspector.loading
                    ? () => ref.read(inspectorProvider.notifier).nextPage()
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTable(
    BuildContext context, {
    required List<ColumnInfo> columns,
    required List<Map<String, Object?>> rows,
    required ValueNotifier<Set<String>> expandedCols,
    required ColorScheme scheme,
    required TextStyle? headerStyle,
    required TextStyle? cellStyle,
    required TextStyle? nullStyle,
  }) {
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder(
        horizontalInside: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
        verticalInside: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.55),
          ),
          children: columns.map((col) {
            final expanded = expandedCols.value.contains(col.name);
            return InkWell(
              onTap: () {
                final s = Set<String>.of(expandedCols.value);
                expanded ? s.remove(col.name) : s.add(col.name);
                expandedCols.value = s;
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(col.name, style: headerStyle),
                    const SizedBox(width: 4),
                    AppIcon(
                      expanded
                          ? HugeIcons.strokeRoundedCollapse
                          : HugeIcons.strokeRoundedExpand,
                      size: 14,
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (rows.isEmpty)
          TableRow(
            children: List.generate(
              columns.length,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: i == 0
                    ? Text('No rows', style: nullStyle)
                    : const SizedBox.shrink(),
              ),
            ),
          )
        else
          ...rows.asMap().entries.map((entry) {
            final idx = entry.key;
            final row = entry.value;
            return TableRow(
              decoration: BoxDecoration(
                color: idx.isEven
                    ? scheme.surfaceContainerHighest.withValues(alpha: 0.15)
                    : null,
              ),
              children: columns.map((col) {
                final v = row[col.name];
                final expanded = expandedCols.value.contains(col.name);
                return _CellWidget(
                  value: v,
                  expanded: expanded,
                  cellStyle: cellStyle,
                  nullStyle: nullStyle,
                );
              }).toList(),
            );
          }),
      ],
    );
  }
}

class _CellWidget extends StatelessWidget {
  const _CellWidget({
    required this.value,
    required this.expanded,
    this.cellStyle,
    this.nullStyle,
  });

  final Object? value;
  final bool expanded;
  final TextStyle? cellStyle;
  final TextStyle? nullStyle;

  static const double _collapsedMaxWidth = 220;

  @override
  Widget build(BuildContext context) {
    final isNull = value == null;
    final text = isNull ? 'NULL' : value.toString();
    final style = isNull ? nullStyle : cellStyle;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: expanded ? double.infinity : _collapsedMaxWidth,
        ),
        child: SelectableText(
          text,
          style: style,
          maxLines: expanded ? null : 2,
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({required this.icon, this.onPressed});
  final List<List<dynamic>> icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton.filledTonal(
        iconSize: 18,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: AppIcon(icon),
      ),
    );
  }
}
