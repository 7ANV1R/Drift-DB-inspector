import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/device.dart';
import '../models/table_info.dart';
import '../services/adb_service.dart';
import '../services/db_service.dart';
import '../widgets/data_table_view.dart';
import '../widgets/device_selector.dart';
import '../widgets/package_input.dart';
import '../widgets/search_bar.dart';
import '../widgets/table_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _pageSize = 50;

  final AdbService _adb = AdbService();
  final DbService _db = DbService();

  final TextEditingController _packageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<AdbDevice> _devices = [];
  String? _selectedSerial;
  List<String> _dbPaths = [];
  String? _selectedRemoteDb;

  List<String> _tables = [];
  String? _selectedTable;
  List<ColumnInfo>? _columns;

  List<Map<String, Object?>> _rows = [];
  int _totalRows = 0;
  int _page = 0;

  bool _loadingDevices = false;
  bool _loadingDiscover = false;
  bool _loadingPull = false;
  bool _loadingRows = false;

  String? _errorMessage;
  String _discoveryLog = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _packageController.dispose();
    _searchController.dispose();
    _db.close();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loadingDevices = true;
      _errorMessage = null;
    });
    try {
      await _adb.findAdb();
      final list = await _adb.listDevices();
      if (!mounted) return;
      setState(() {
        _devices = list;
        if (_selectedSerial == null) {
          final ready = list.where((d) => d.isReady).toList();
          if (ready.length == 1) {
            _selectedSerial = ready.first.serial;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(e);
      });
    } finally {
      if (mounted) {
        setState(() => _loadingDevices = false);
      }
    }
  }

  Future<void> _discoverDatabases() async {
    final serial = _selectedSerial;
    final pkg = _packageController.text.trim();
    if (serial == null || pkg.isEmpty) {
      setState(() {
        _errorMessage =
            'Select a device and enter the application ID (package name).';
      });
      return;
    }
    setState(() {
      _loadingDiscover = true;
      _errorMessage = null;
      _discoveryLog = '';
    });
    try {
      final result = await _adb.discoverDatabases(serial, pkg);
      final paths = result.paths;
      if (!mounted) return;
      setState(() {
        _dbPaths = paths;
        _discoveryLog = result.log;
        _selectedRemoteDb = paths.contains(_selectedRemoteDb)
            ? _selectedRemoteDb
            : null;
        if (_selectedRemoteDb == null && paths.length == 1) {
          _selectedRemoteDb = paths.first;
        }
      });

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (paths.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            content: const Text(
              'No SQLite files matched. Open “Discovery log” below Connection for full adb '
              'output (each strategy + stdout/stderr previews).',
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              paths.length == 1
                  ? 'Found 1 database file. Select it and tap Pull & inspect.'
                  : 'Found ${paths.length} database files.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(e);
        _dbPaths = [];
        _selectedRemoteDb = null;
        _discoveryLog =
            'Discovery stopped with an error (partial log may be missing):\n\n$e';
      });
    } finally {
      if (mounted) setState(() => _loadingDiscover = false);
    }
  }

  Future<void> _pullAndOpen({bool showError = true}) async {
    final serial = _selectedSerial;
    final pkg = _packageController.text.trim();
    final remote = _selectedRemoteDb;
    if (serial == null || pkg.isEmpty || remote == null) {
      if (showError) {
        setState(() {
          _errorMessage = 'Select device, application ID, and a database file.';
        });
      }
      return;
    }

    setState(() {
      _loadingPull = true;
      _errorMessage = null;
    });
    try {
      final temp = await getTemporaryDirectory();
      final localDir = p.join(
        temp.path,
        'drift_db_inspector',
        serial,
        pkg.replaceAll('.', '_'),
      );
      final localPath = await _adb.pullDatabase(serial, pkg, remote, localDir);
      _db.openDatabase(localPath);
      final tables = _db.getTables();
      if (!mounted) return;
      setState(() {
        _tables = tables;
        _selectedTable = tables.isNotEmpty ? tables.first : null;
        _columns = _selectedTable != null
            ? _db.getTableColumns(_selectedTable!)
            : null;
        _page = 0;
        _searchController.clear();
      });
      await _loadRows();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database opened — browse tables on the left.'),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('Drift DB Inspector: Pull & inspect failed: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(e);
        _tables = [];
        _selectedTable = null;
        _columns = null;
        _rows = [];
        _totalRows = 0;
      });
    } finally {
      if (mounted) setState(() => _loadingPull = false);
    }
  }

  Future<void> _loadRows() async {
    final table = _selectedTable;
    if (table == null || !_db.isOpen) {
      setState(() {
        _rows = [];
        _totalRows = 0;
      });
      return;
    }

    setState(() => _loadingRows = true);
    try {
      var cols = _columns ?? _db.getTableColumns(table);
      _columns = cols;
      final q = _searchController.text.trim();
      final total = _db.getRowCount(
        table,
        searchQuery: q.isEmpty ? null : q,
        columns: cols,
      );
      final data = _db.getRows(
        table,
        limit: _pageSize,
        offset: _page * _pageSize,
        searchQuery: q.isEmpty ? null : q,
        columns: cols,
      );
      if (!mounted) return;
      setState(() {
        _totalRows = total;
        _rows = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(e);
        _rows = [];
        _totalRows = 0;
      });
    } finally {
      if (mounted) setState(() => _loadingRows = false);
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _page = 0);
      _loadRows();
    });
  }

  void _onSelectTable(String name) {
    setState(() {
      _selectedTable = name;
      _columns = _db.getTableColumns(name);
      _page = 0;
      _searchController.clear();
    });
    _loadRows();
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (e is FormatException &&
        s.contains('extension byte') &&
        s.contains('Unexpected')) {
      return 'Binary decode error while reading adb output (this build should be fixed). '
          'If it persists, file an issue with the full Debug Console log.\n$s';
    }
    if (s.contains('SqliteException') || s.contains('database disk image')) {
      return 'Database file looks corrupt or incomplete. '
          'Try Pull again; ensure WAL/SHM were copied (debug build, app not holding a lock).';
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dbOpen = _db.isOpen;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    scheme.primary,
                    Color.lerp(scheme.primary, scheme.tertiary, 0.45)!,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.storage_rounded,
                  color: scheme.onPrimary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Drift DB Inspector',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                Text(
                  'ADB · read-only · local copy',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (dbOpen)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: _loadingPull
                    ? null
                    : () => _pullAndOpen(showError: true),
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Re-sync'),
              ),
            ),
        ],
      ),
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Material(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: scheme.onErrorContainer,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SelectableText(
                            _errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onErrorContainer,
                              height: 1.35,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Dismiss',
                          onPressed: () => setState(() => _errorMessage = null),
                          icon: Icon(
                            Icons.close_rounded,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.45),
                      scheme.tertiary.withValues(alpha: 0.35),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(1.5),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: scheme.surfaceContainerLow,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.hub_outlined,
                                color: scheme.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Connection',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Choose your Android device, paste the app package name, then discover SQLite files.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                flex: 5,
                                child: DeviceSelector(
                                  devices: _devices,
                                  selectedSerial: _selectedSerial,
                                  busy: _loadingDevices,
                                  onRefresh: _loadDevices,
                                  onChanged: (s) =>
                                      setState(() => _selectedSerial = s),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 6,
                                child: PackageInput(
                                  controller: _packageController,
                                  enabled: !_loadingPull,
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: _loadingDiscover
                                    ? null
                                    : _discoverDatabases,
                                icon: _loadingDiscover
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: scheme.onPrimary,
                                        ),
                                      )
                                    : const Icon(Icons.travel_explore_rounded),
                                label: const Text('Discover DBs'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'SQLite file on device',
                                    prefixIcon: Icon(
                                      Icons.insert_drive_file_outlined,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      isDense: true,
                                      borderRadius: BorderRadius.circular(14),
                                      value:
                                          _selectedRemoteDb != null &&
                                              _dbPaths.contains(
                                                _selectedRemoteDb,
                                              )
                                          ? _selectedRemoteDb
                                          : null,
                                      hint: Text(
                                        _dbPaths.isEmpty
                                            ? 'Run Discover DBs first'
                                            : 'Pick a database',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                      items: _dbPaths
                                          .map(
                                            (path) => DropdownMenuItem(
                                              value: path,
                                              child: Text(
                                                path,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: _loadingPull
                                          ? null
                                          : (v) => setState(
                                              () => _selectedRemoteDb = v,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed:
                                    (_loadingPull ||
                                        _selectedRemoteDb == null ||
                                        _selectedSerial == null)
                                    ? null
                                    : () => _pullAndOpen(),
                                icon: const Icon(Icons.downloading_rounded),
                                label: Text(
                                  _db.isOpen ? 'Pull again' : 'Pull & inspect',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_discoveryLog.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: ExpansionTile(
                    initiallyExpanded: _dbPaths.isEmpty,
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    title: Row(
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 20,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Discovery log',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'Per-step exit codes, stderr, and stdout previews from adb',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    children: [
                      SizedBox(
                        height: 240,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(
                              alpha: 0.4,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: SelectableText(
                              _discoveryLog,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11.5,
                                height: 1.35,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 268,
                      child: Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.view_list_rounded,
                                    size: 20,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Tables',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: TableList(
                                tables: _tables,
                                selectedTable: _selectedTable,
                                onSelect: _onSelectTable,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedTable == null
                                          ? 'Data preview'
                                          : _selectedTable!,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.2,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TableSearchBar(
                                controller: _searchController,
                                enabled: _selectedTable != null && dbOpen,
                                onChanged: _onSearchChanged,
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: DataTableView(
                                  columns: _columns ?? const [],
                                  rows: _rows,
                                  totalRows: _totalRows,
                                  pageZeroBased: _page,
                                  pageSize: _pageSize,
                                  loading: _loadingRows || _loadingPull,
                                  onPrevPage: _selectedTable == null
                                      ? () {}
                                      : () {
                                          if (_page > 0) {
                                            setState(() => _page--);
                                            _loadRows();
                                          }
                                        },
                                  onNextPage: _selectedTable == null
                                      ? () {}
                                      : () {
                                          final last =
                                              (_totalRows / _pageSize).ceil() -
                                              1;
                                          if (_page < last) {
                                            setState(() => _page++);
                                            _loadRows();
                                          }
                                        },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
