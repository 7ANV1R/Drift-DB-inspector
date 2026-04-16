import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/database_discovery_result.dart';
import '../models/simulator_device.dart';

class IosSimulatorService {
  IosSimulatorService();

  bool get isSupportedHost => Platform.isMacOS;

  Future<List<IosSimulatorDevice>> listDevices() async {
    if (!isSupportedHost) return const [];

    final result = await Process.run(
      'xcrun',
      ['simctl', 'list', 'devices', 'available', '-j'],
      stderrEncoding: systemEncoding,
      stdoutEncoding: systemEncoding,
    );
    if (result.exitCode != 0) {
      throw SimulatorException(
        'simctl list failed (is Xcode installed?):\n${result.stderr}',
      );
    }

    final decoded = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final devicesSection =
        decoded['devices'] as Map<String, dynamic>? ?? const {};
    final out = <IosSimulatorDevice>[];

    for (final e in devicesSection.entries) {
      final runtime = e.key;
      final list = e.value;
      if (list is! List) continue;
      for (final raw in list) {
        if (raw is! Map<String, dynamic>) continue;
        if (raw['isAvailable'] != true) continue;
        final udid = raw['udid'] as String?;
        final name = raw['name'] as String?;
        if (udid == null || name == null) continue;
        out.add(
          IosSimulatorDevice(
            udid: udid,
            name: name,
            state: raw['state'] as String? ?? 'Unknown',
            runtime: runtime,
          ),
        );
      }
    }

    out.sort((a, b) {
      final boot = (b.isBooted ? 1 : 0).compareTo(a.isBooted ? 1 : 0);
      if (boot != 0) return boot;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  Future<DatabaseDiscoveryResult> discoverDatabases(
    String udid,
    String bundleId,
  ) async {
    if (!isSupportedHost) {
      throw SimulatorException('iOS Simulator browsing needs a Mac host.');
    }
    _assertBundleId(bundleId);

    final log = StringBuffer()
      ..writeln('=== iOS Simulator database discovery ===')
      ..writeln('Time: ${DateTime.now().toIso8601String()}')
      ..writeln('UDID: $udid')
      ..writeln('Bundle ID: $bundleId')
      ..writeln('');

    final containerResult = await Process.run(
      'xcrun',
      ['simctl', 'get_app_container', udid, bundleId, 'data'],
      stderrEncoding: systemEncoding,
      stdoutEncoding: systemEncoding,
    );

    log.writeln('get_app_container exit: ${containerResult.exitCode}');
    if (containerResult.stderr.toString().trim().isNotEmpty) {
      log.writeln('stderr:\n${containerResult.stderr}');
    }

    if (containerResult.exitCode != 0) {
      throw SimulatorException(
        'Could not open data container for "$bundleId". '
        'Install the app on this simulator and try again.\n'
        '${containerResult.stderr}',
      );
    }

    final container = containerResult.stdout.toString().trim();
    log.writeln('Data container:\n$container\n');

    final sqliteFiles = await _findSqliteUnder(Directory(container));
    sqliteFiles.sort();
    log.writeln('SQLite files: ${sqliteFiles.length}');
    for (final f in sqliteFiles) {
      log.writeln('  + $f');
    }

    return DatabaseDiscoveryResult(paths: sqliteFiles, log: log.toString());
  }

  /// Copies a database from the simulator data volume into [localDir] (macOS paths).
  Future<String> copyDatabase(String remoteHostPath, String localDir) async {
    if (!isSupportedHost) {
      throw SimulatorException('Copy needs a Mac host.');
    }
    final src = File(remoteHostPath);
    if (!await src.exists()) {
      throw SimulatorException('File not found:\n$remoteHostPath');
    }

    await Directory(localDir).create(recursive: true);
    final baseName = p.basename(remoteHostPath);
    final localMain = p.join(localDir, baseName);
    await src.copy(localMain);

    final lower = remoteHostPath.toLowerCase();
    if (lower.endsWith('.db') ||
        lower.endsWith('.sqlite') ||
        lower.endsWith('.sqlite3')) {
      for (final suffix in <String>['-wal', '-shm']) {
        final companion = File('$remoteHostPath$suffix');
        if (await companion.exists()) {
          await companion.copy(p.join(localDir, '$baseName$suffix'));
        }
      }
    }

    return localMain;
  }

  Future<List<String>> _findSqliteUnder(Directory root) async {
    if (!await root.exists()) return [];
    final files = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (_looksLikeSqlitePath(entity.path)) {
        files.add(entity.path);
      }
    }
    return files;
  }

  void _assertBundleId(String bundleId) {
    if (bundleId.isEmpty) {
      throw SimulatorException('Bundle ID is required.');
    }
    if (!RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(bundleId)) {
      throw SimulatorException(
        'Bundle ID has invalid characters (use letters, numbers, dots, -, _).',
      );
    }
    if (!bundleId.contains('.')) {
      throw SimulatorException('Bundle ID should look like com.company.app');
    }
  }

  bool _looksLikeSqlitePath(String path) {
    final name = p.basename(path).toLowerCase();
    if (name.endsWith('-journal') ||
        name.endsWith('-wal') ||
        name.endsWith('-shm')) {
      return false;
    }
    return RegExp(
      r'\.(sqlite3?|db(\.sqlite)?)$',
      caseSensitive: false,
    ).hasMatch(name);
  }
}

class SimulatorException implements Exception {
  SimulatorException(this.message);
  final String message;

  @override
  String toString() => message;
}
