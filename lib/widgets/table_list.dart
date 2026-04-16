import 'package:flutter/material.dart';

class TableList extends StatelessWidget {
  const TableList({
    super.key,
    required this.tables,
    required this.selectedTable,
    required this.onSelect,
  });

  final List<String> tables;
  final String? selectedTable;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (tables.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.table_chart_outlined,
                size: 40,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              Text(
                'Pull a database to see tables',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final name = tables[index];
        final selected = name == selectedTable;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: selected
                ? scheme.primaryContainer.withValues(alpha: 0.55)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelect(name),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.grid_on_rounded,
                      size: 18,
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          letterSpacing: -0.1,
                          color: selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
