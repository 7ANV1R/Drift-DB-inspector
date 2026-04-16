import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/connect_backend.dart';
import '../models/database_discovery_result.dart';
import '../models/table_info.dart';
import '../services/adb_service.dart';
import '../services/db_service.dart';
import '../services/ios_simulator_service.dart';
import 'adb_provider.dart';
import 'simulator_provider.dart';

final dbServiceProvider = Provider<DbService>((ref) => DbService());

/// Holds entire inspector state after a database is opened.
class InspectorState {
  const InspectorState({
    required this.backend,
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

  /// Android serial, or iOS Simulator UDID.
  final ConnectBackend backend;
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
      backend: backend,
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

/// Label for the macOS transparent title-bar strip (connect vs inspector).
final macosTitleBarLabelProvider = Provider<String>((ref) {
  final inspector = ref.watch(inspectorProvider);
  if (inspector == null) {
    return 'Drift Db Inspector';
  }
  final fileName = p.basename(inspector.remoteDbPath);
  return '${inspector.packageName} · $fileName';
});

class InspectorNotifier extends Notifier<InspectorState?> {
  @override
  InspectorState? build() => null;

  DbService get _db => ref.read(dbServiceProvider);
  AdbService get _adb => ref.read(adbServiceProvider);
  IosSimulatorService get _ios => ref.read(iosSimulatorServiceProvider);

  /// Lets the UI frame between heavy synchronous SQLite work on the isolate.
  Future<void> _yieldToUi() => Future<void>.delayed(Duration.zero);

  Future<void> openDatabase({
    required ConnectBackend backend,
    required String serial,
    required String packageName,
    required String remoteDbPath,
  }) async {
    state = InspectorState(
      backend: backend,
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
      final localPath = await _pullDb(
        backend,
        serial,
        packageName,
        remoteDbPath,
      );
      await _yieldToUi();
      _db.openDatabase(localPath);
      await _yieldToUi();
      final tables = _db.getTables();
      await _yieldToUi();
      final first = tables.isNotEmpty ? tables.first : null;
      final columns =
          first != null ? _db.getTableColumns(first) : const <ColumnInfo>[];
      await _yieldToUi();
      state = InspectorState(
        backend: backend,
        serial: serial,
        packageName: packageName,
        remoteDbPath: remoteDbPath,
        tables: tables,
        selectedTable: first,
        columns: columns,
        rows: const [],
        totalRows: 0,
        page: 0,
        searchQuery: '',
      );
      if (first != null) {
        await _yieldToUi();
        _loadRows();
      }
    } catch (e) {
      state = state?.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    final s = state;
    if (s == null) return;
    await openDatabase(
      backend: s.backend,
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
    ConnectBackend backend,
    String serial,
    String packageName,
    String remoteDbPath,
  ) async {
    if (backend == ConnectBackend.localFile) {
      final f = File(remoteDbPath);
      if (!await f.exists()) {
        throw StateError('File not found: $remoteDbPath');
      }
      return p.normalize(remoteDbPath);
    }

    final temp = await getTemporaryDirectory();
    final bucket = backend == ConnectBackend.adb ? 'adb' : 'ios';
    final localDir = p.join(
      temp.path,
      'drift_db_inspector',
      bucket,
      serial,
      packageName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_'),
    );
    if (backend == ConnectBackend.adb) {
      return _adb.pullDatabase(serial, packageName, remoteDbPath, localDir);
    }
    return _ios.copyDatabase(remoteDbPath, localDir);
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
    ConnectBackend backend,
    String deviceId,
    String packageName,
  ) async {
    state = const AsyncLoading();
    try {
      final DatabaseDiscoveryResult result;
      switch (backend) {
        case ConnectBackend.adb:
          result = await ref
              .read(adbServiceProvider)
              .discoverDatabases(deviceId, packageName);
        case ConnectBackend.iosSimulator:
          result = await ref
              .read(iosSimulatorServiceProvider)
              .discoverDatabases(deviceId, packageName);
        case ConnectBackend.localFile:
          throw UnsupportedError('Use file picker for local databases.');
      }
      state = AsyncData(result);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
