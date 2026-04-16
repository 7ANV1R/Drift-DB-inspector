import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/database_discovery_result.dart';
import '../models/table_info.dart';
import '../services/adb_service.dart';
import '../services/db_service.dart';

final dbServiceProvider = Provider<DbService>((ref) => DbService());

/// Holds entire inspector state after a database is opened.
class InspectorState {
  const InspectorState({
    required this.serial,
    required this.packageName,
    required this.remoteDbPath,
    required this.tables,
    required this.selectedTable,
    required this.columns,
    required this.rows,
    required this.totalRows,
    required this.page,
    required this.searchQuery,
    this.loading = false,
    this.error,
  });

  final String serial;
  final String packageName;
  final String remoteDbPath;
  final List<String> tables;
  final String? selectedTable;
  final List<ColumnInfo> columns;
  final List<Map<String, Object?>> rows;
  final int totalRows;
  final int page;
  final String searchQuery;
  final bool loading;
  final String? error;

  static const int pageSize = 50;

  InspectorState copyWith({
    String? selectedTable,
    List<ColumnInfo>? columns,
    List<Map<String, Object?>>? rows,
    int? totalRows,
    int? page,
    String? searchQuery,
    bool? loading,
    String? error,
    List<String>? tables,
  }) {
    return InspectorState(
      serial: serial,
      packageName: packageName,
      remoteDbPath: remoteDbPath,
      tables: tables ?? this.tables,
      selectedTable: selectedTable ?? this.selectedTable,
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      totalRows: totalRows ?? this.totalRows,
      page: page ?? this.page,
      searchQuery: searchQuery ?? this.searchQuery,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

final inspectorProvider = NotifierProvider<InspectorNotifier, InspectorState?>(
  InspectorNotifier.new,
);

class InspectorNotifier extends Notifier<InspectorState?> {
  @override
  InspectorState? build() => null;

  DbService get _db => ref.read(dbServiceProvider);
  AdbService get _adb => ref.read(adbServiceProvider);

  Future<void> openDatabase({
    required String serial,
    required String packageName,
    required String remoteDbPath,
  }) async {
    state = InspectorState(
      serial: serial,
      packageName: packageName,
      remoteDbPath: remoteDbPath,
      tables: const [],
      selectedTable: null,
      columns: const [],
      rows: const [],
      totalRows: 0,
      page: 0,
      searchQuery: '',
      loading: true,
    );
    try {
      final localPath = await _pullDb(serial, packageName, remoteDbPath);
      _db.openDatabase(localPath);
      final tables = _db.getTables();
      final first = tables.isNotEmpty ? tables.first : null;
      state = InspectorState(
        serial: serial,
        packageName: packageName,
        remoteDbPath: remoteDbPath,
        tables: tables,
        selectedTable: first,
        columns: first != null ? _db.getTableColumns(first) : const [],
        rows: const [],
        totalRows: 0,
        page: 0,
        searchQuery: '',
      );
      if (first != null) _loadRows();
    } catch (e) {
      state = state?.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    final s = state;
    if (s == null) return;
    await openDatabase(
      serial: s.serial,
      packageName: s.packageName,
      remoteDbPath: s.remoteDbPath,
    );
  }

  void selectTable(String name) {
    final s = state;
    if (s == null) return;
    final cols = _db.getTableColumns(name);
    state = s.copyWith(
      selectedTable: name,
      columns: cols,
      rows: const [],
      totalRows: 0,
      page: 0,
      searchQuery: '',
    );
    _loadRows();
  }

  void setSearch(String query) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(searchQuery: query, page: 0);
    _loadRows();
  }

  void prevPage() {
    final s = state;
    if (s == null || s.page <= 0) return;
    state = s.copyWith(page: s.page - 1);
    _loadRows();
  }

  void nextPage() {
    final s = state;
    if (s == null) return;
    final lastPage = (s.totalRows / InspectorState.pageSize).ceil() - 1;
    if (s.page >= lastPage) return;
    state = s.copyWith(page: s.page + 1);
    _loadRows();
  }

  void close() {
    _db.close();
    state = null;
  }

  void _loadRows() {
    final s = state;
    if (s == null || s.selectedTable == null) return;
    state = s.copyWith(loading: true);
    try {
      final q = s.searchQuery.trim();
      final total = _db.getRowCount(
        s.selectedTable!,
        searchQuery: q.isEmpty ? null : q,
        columns: s.columns,
      );
      final rows = _db.getRows(
        s.selectedTable!,
        limit: InspectorState.pageSize,
        offset: s.page * InspectorState.pageSize,
        searchQuery: q.isEmpty ? null : q,
        columns: s.columns,
      );
      state = s.copyWith(rows: rows, totalRows: total, loading: false);
    } catch (e) {
      state = s.copyWith(loading: false, error: e.toString());
    }
  }

  Future<String> _pullDb(
    String serial,
    String packageName,
    String remoteDbPath,
  ) async {
    final temp = await getTemporaryDirectory();
    final localDir = p.join(
      temp.path,
      'drift_db_inspector',
      serial,
      packageName.replaceAll('.', '_'),
    );
    return _adb.pullDatabase(serial, packageName, remoteDbPath, localDir);
  }
}

/// Discovery result holder
final discoveryProvider =
    AsyncNotifierProvider<DiscoveryNotifier, DatabaseDiscoveryResult?>(
      DiscoveryNotifier.new,
    );

class DiscoveryNotifier extends AsyncNotifier<DatabaseDiscoveryResult?> {
  @override
  Future<DatabaseDiscoveryResult?> build() async => null;

  Future<DatabaseDiscoveryResult> discover(
    String serial,
    String packageName,
  ) async {
    state = const AsyncLoading();
    final adb = ref.read(adbServiceProvider);
    final result = await adb.discoverDatabases(serial, packageName);
    state = AsyncData(result);
    return result;
  }
}

final adbServiceProvider = Provider<AdbService>((ref) => AdbService());
