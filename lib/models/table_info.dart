/// Column metadata from `PRAGMA table_info`.
class ColumnInfo {
  const ColumnInfo({
    required this.cid,
    required this.name,
    required this.type,
    required this.notNull,
    required this.defaultValue,
    required this.pk,
  });

  final int cid;
  final String name;
  final String type;
  final bool notNull;
  final String? defaultValue;
  final int pk;

  /// Whether this column is a good candidate for text search (LIKE).
  bool get isTextSearchable {
    final t = type.toUpperCase();
    return t.contains('CHAR') ||
        t.contains('CLOB') ||
        t.contains('TEXT') ||
        t.isEmpty;
  }
}
