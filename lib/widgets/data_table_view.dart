import 'package:flutter/material.dart';

import '../models/table_info.dart';

class DataTableView extends StatelessWidget {
  const DataTableView({
    super.key,
    required this.columns,
    required this.rows,
    required this.totalRows,
    required this.pageZeroBased,
    required this.pageSize,
    required this.onPrevPage,
    required this.onNextPage,
    this.loading = false,
  });

  final List<ColumnInfo> columns;
  final List<Map<String, Object?>> rows;
  final int totalRows;
  final int pageZeroBased;
  final int pageSize;
  final VoidCallback onPrevPage;
  final VoidCallback onNextPage;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final start = totalRows == 0 ? 0 : pageZeroBased * pageSize + 1;
    final end = (pageZeroBased + 1) * pageSize;
    final endClamped = end > totalRows ? totalRows : end;
    final lastPage = (totalRows / pageSize).ceil() - 1;
    final hasPrev = pageZeroBased > 0;
    final hasNext = pageZeroBased < lastPage;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: columns.isEmpty
                      ? Center(
                          child: Text(
                            'Select a table',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: Table(
                              defaultColumnWidth: const IntrinsicColumnWidth(),
                              border: TableBorder(
                                horizontalInside: BorderSide(
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                                verticalInside: BorderSide(
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                              ),
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer.withValues(
                                      alpha: 0.65,
                                    ),
                                  ),
                                  children: columns
                                      .map(
                                        (c) => _cell(
                                          context,
                                          c.name,
                                          header: true,
                                          mono: false,
                                        ),
                                      )
                                      .toList(),
                                ),
                                if (rows.isEmpty)
                                  TableRow(
                                    children: List.generate(
                                      columns.length.clamp(1, 999),
                                      (i) => i == 0
                                          ? _cell(
                                              context,
                                              'No rows in this table',
                                              header: false,
                                              mono: false,
                                            )
                                          : _cell(context, '', header: false),
                                    ),
                                  )
                                else
                                  ...rows.asMap().entries.map((entry) {
                                    final stripe = entry.key.isEven;
                                    final row = entry.value;
                                    return TableRow(
                                      decoration: BoxDecoration(
                                        color: stripe
                                            ? scheme.surfaceContainerHighest
                                                  .withValues(alpha: 0.2)
                                            : null,
                                      ),
                                      children: columns
                                          .map(
                                            (c) => _cell(
                                              context,
                                              _formatValue(row[c.name]),
                                              header: false,
                                              mono: true,
                                            ),
                                          )
                                          .toList(),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  totalRows == 0
                      ? '0 rows'
                      : 'Rows $start–$endClamped of $totalRows',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: hasPrev && !loading ? onPrevPage : null,
                  icon: const Icon(Icons.chevron_left_rounded, size: 22),
                  label: const Text('Prev'),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    totalRows == 0
                        ? '—'
                        : '${pageZeroBased + 1} / ${lastPage + 1}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: hasNext && !loading ? onNextPage : null,
                  icon: const Icon(Icons.chevron_right_rounded, size: 22),
                  label: const Text('Next'),
                ),
              ],
            ),
          ],
        ),
        if (loading)
          Positioned.fill(
            child: ColoredBox(
              color: scheme.surface.withValues(alpha: 0.55),
              child: Center(
                child: CircularProgressIndicator(
                  color: scheme.primary,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _formatValue(Object? v) {
    if (v == null) return 'null';
    return v.toString();
  }

  Widget _cell(
    BuildContext context,
    String text, {
    required bool header,
    bool mono = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SelectableText(
        text,
        style: (header ? theme.textTheme.labelLarge : theme.textTheme.bodySmall)
            ?.copyWith(
              fontFamily: mono ? 'monospace' : null,
              fontWeight: header ? FontWeight.w700 : FontWeight.w400,
              letterSpacing: header ? 0.2 : 0,
              color: header ? scheme.onPrimaryContainer : scheme.onSurface,
            ),
      ),
    );
  }
}
