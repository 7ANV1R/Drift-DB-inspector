import 'package:sqlite3/sqlite3.dart';

import '../models/table_info.dart';

/// Read-only SQLite access for inspection (local file copied from device).
class DbService {
  Database? _db;

  bool get isOpen => _db != null;

  void openDatabase(String path) {
    close();
    try {
      _db = sqlite3.open(path, mode: OpenMode.readOnly);
    } catch (e, st) {
      throw DbException('Could not open database: $e\n$st');
    }
  }

  void close() {
    _db?.close();
    _db = null;
  }

  Database get _require {
    final d = _db;
    if (d == null) {
      throw DbException('No database open.');
    }
    return d;
  }

  List<String> getTables() {
    final stmt = _require.prepare(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    try {
      final rows = stmt.select([]);
      return rows.map((r) => r['name'] as String).toList();
    } finally {
      stmt.close();
    }
  }

  List<ColumnInfo> getTableColumns(String table) {
    _validateIdentifier(table);
    final stmt = _require.prepare(
      'PRAGMA table_info("${_escapeIdent(table)}")',
    );
    try {
      final rows = stmt.select([]);
      return rows.map((r) {
        return ColumnInfo(
          cid: r['cid'] as int,
          name: r['name'] as String,
          type: (r['type'] as String?) ?? '',
          notNull: (r['notnull'] as int) != 0,
          defaultValue: r['dflt_value'] as String?,
          pk: r['pk'] as int,
        );
      }).toList();
    } finally {
      stmt.close();
    }
  }

  int getRowCount(
    String table, {
    String? searchQuery,
    List<ColumnInfo>? columns,
  }) {
    _validateIdentifier(table);
    final cols = columns ?? getTableColumns(table);
    final where = _searchWhereClause(cols, searchQuery);
    final sql =
        'SELECT COUNT(*) AS c FROM "${_escapeIdent(table)}"${where.clause}';
    final stmt = _require.prepare(sql);
    try {
      final rows = stmt.select(where.args);
      final c = rows.first['c'];
      if (c is int) return c;
      if (c is BigInt) return c.toInt();
      return (c as num).toInt();
    } finally {
      stmt.close();
    }
  }

  /// Returns rows as list of maps columnName -> displayable value.
  List<Map<String, Object?>> getRows(
    String table, {
    required int limit,
    required int offset,
    String? searchQuery,
    List<ColumnInfo>? columns,
  }) {
    _validateIdentifier(table);
    final cols = columns ?? getTableColumns(table);
    final where = _searchWhereClause(cols, searchQuery);
    final sql =
        'SELECT * FROM "${_escapeIdent(table)}"${where.clause} LIMIT ? OFFSET ?';
    final args = <Object?>[...where.args, limit, offset];
    final stmt = _require.prepare(sql);
    try {
      final result = stmt.select(args);
      return result.map((row) {
        final map = <String, Object?>{};
        for (final col in cols) {
          final v = row[col.name];
          map[col.name] = _formatCell(v);
        }
        return map;
      }).toList();
    } finally {
      stmt.close();
    }
  }

  static Object? _formatCell(Object? value) {
    if (value == null) return null;
    if (value is List<int>) {
      return '(BLOB, ${value.length} bytes)';
    }
    return value;
  }

  _WhereParts _searchWhereClause(
    List<ColumnInfo> columns,
    String? searchQuery,
  ) {
    final q = searchQuery?.trim();
    if (q == null || q.isEmpty) {
      return _WhereParts('', []);
    }
    final textCols = columns.where((c) => c.isTextSearchable).toList();
    if (textCols.isEmpty) {
      return _WhereParts('', []);
    }
    final pattern = '%${_escapeLike(q)}%';
    final parts = <String>[];
    final args = <Object?>[];
    for (final c in textCols) {
      _validateIdentifier(c.name);
      parts.add('"${_escapeIdent(c.name)}" LIKE ? ESCAPE \'\\\'');
      args.add(pattern);
    }
    return _WhereParts(' WHERE (${parts.join(' OR ')})', args);
  }

  static String _escapeLike(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  static void _validateIdentifier(String name) {
    if (name.isEmpty) throw DbException('Invalid identifier');
    if (!RegExp(r'^[\w\$]+$').hasMatch(name)) {
      throw DbException('Invalid SQL identifier: $name');
    }
  }

  static String _escapeIdent(String name) => name.replaceAll('"', '""');
}

class _WhereParts {
  _WhereParts(this.clause, this.args);
  final String clause;
  final List<Object?> args;
}

class DbException implements Exception {
  DbException(this.message);
  final String message;

  @override
  String toString() => message;
}
