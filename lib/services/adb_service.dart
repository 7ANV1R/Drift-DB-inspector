import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/database_discovery_result.dart';
import '../models/device.dart';

class AdbService {
  AdbService();

  String? _cachedAdbPath;

  Future<String> findAdb() async {
    if (_cachedAdbPath != null) {
      final f = File(_cachedAdbPath!);
      if (await f.exists()) return _cachedAdbPath!;
    }

    final which = await Process.run('which', ['adb']);
    if (which.exitCode == 0) {
      final path = which.stdout.toString().trim().split('\n').first.trim();
      if (path.isNotEmpty && await File(path).exists()) {
        _cachedAdbPath = path;
        return path;
      }
    }

    final home = Platform.environment['HOME'] ?? '';
    final candidates = <String>[
      '/opt/homebrew/bin/adb',
      '/usr/local/bin/adb',
      if (home.isNotEmpty)
        p.join(home, 'Library/Android/sdk/platform-tools/adb'),
    ];

    for (final path in candidates) {
      if (await File(path).exists()) {
        _cachedAdbPath = path;
        return path;
      }
    }

    throw AdbException(
      'Could not find adb. Install Android SDK platform-tools and ensure adb is on PATH, '
      'or place it at ~/Library/Android/sdk/platform-tools/adb.',
    );
  }

  Future<List<AdbDevice>> listDevices() async {
    final adb = await findAdb();
    final result = await Process.run(adb, [
      'devices',
      '-l',
    ], stderrEncoding: systemEncoding);
    if (result.exitCode != 0) {
      throw AdbException('adb devices failed: ${result.stderr}');
    }

    final lines = result.stdout.toString().split('\n');
    final devices = <AdbDevice>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('List of devices')) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final serial = parts[0];
      final state = parts[1];
      String? model;
      final m = RegExp(r'model:(\S+)').firstMatch(trimmed);
      if (m != null) model = m.group(1)?.replaceAll('_', ' ');
      devices.add(AdbDevice(serial: serial, state: state, model: model));
    }
    return devices;
  }

  /// Runs exactly: `adb -s <serial> shell "run-as <pkg> find <dataRoot> -type f"`
  /// One round-trip, one simple command — mirrors user's working terminal command.
  /// Filters extensions in Dart.
  Future<DatabaseDiscoveryResult> discoverDatabases(
    String serial,
    String packageName,
  ) async {
    final adb = await findAdb();
    if (packageName.isEmpty) throw AdbException('Package name is required.');
    _assertSafePackageName(packageName);

    final dataRoot = '/data/data/$packageName';
    final log = StringBuffer()
      ..writeln('=== Database discovery ===')
      ..writeln('Time: ${DateTime.now().toIso8601String()}')
      ..writeln('Serial: $serial')
      ..writeln('Package: $packageName')
      ..writeln('dataRoot: $dataRoot')
      ..writeln('');

    // Exactly: adb shell "run-as <pkg> find <dataRoot> -type f"
    // Pass entire command as single string to `adb shell` so adb sends it
    // verbatim to device sh. This is how terminal `adb shell "..."` works.
    final shellCmd = 'run-as $packageName find $dataRoot -type f';
    log.writeln('Command: adb -s $serial shell "$shellCmd"');
    log.writeln('');

    final result = await Process.run(
      adb,
      ['-s', serial, 'shell', shellCmd],
      stdoutEncoding: systemEncoding,
      stderrEncoding: systemEncoding,
    );

    final out = result.stdout.toString();
    final err = result.stderr.toString();
    log.writeln('exitCode: ${result.exitCode}');
    log.writeln('stdout: ${out.length} chars');
    log.writeln('stderr: ${err.length} chars');
    if (err.trim().isNotEmpty) {
      log.writeln('stderr:\n${_preview(err, 3000)}');
    }
    if (out.trim().isNotEmpty) {
      log.writeln('stdout:\n${_preview(out, 3000)}');
    }
    log.writeln('');

    if (result.exitCode != 0 && _isRunAsFailure(err, out)) {
      _throwListDatabasesError(result, packageName);
    }

    final allFiles = out
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.startsWith('/'))
        .toList();

    log.writeln('Total files listed: ${allFiles.length}');

    final sqliteFiles = allFiles.where((f) => _looksLikeSqlitePath(f)).toList()
      ..sort();

    log.writeln('SQLite files after filter: ${sqliteFiles.length}');
    for (final f in sqliteFiles) {
      log.writeln('  + $f');
    }
    if (sqliteFiles.isEmpty && allFiles.isNotEmpty) {
      log.writeln('');
      log.writeln('No SQLite extension matched. All files found:');
      for (final f in allFiles) {
        log.writeln('  - $f');
      }
    }

    return DatabaseDiscoveryResult(paths: sqliteFiles, log: log.toString());
  }

  void _assertSafePackageName(String packageName) {
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(packageName)) {
      throw AdbException(
        'Package name invalid: letters, digits, dots, underscore only.',
      );
    }
    if (!packageName.contains('.')) {
      throw AdbException(
        'Package name needs at least one dot (e.g. com.company.app).',
      );
    }
  }

  String _preview(String s, int max) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}\n… (${t.length - max} more chars)';
  }

  bool _isRunAsFailure(String stderr, String stdout) {
    final c = '$stderr$stdout'.toLowerCase();
    return c.contains('run-as:') ||
        c.contains('not debuggable') ||
        c.contains('unknown package') ||
        c.contains('package not debuggable') ||
        c.contains('could not set capabilities');
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

  void _throwListDatabasesError(ProcessResult result, String packageName) {
    developer.log(
      'listDatabases failed exit=${result.exitCode} stderr=${result.stderr}',
      name: 'AdbService',
    );
    if (_isRunAsFailure(result.stderr.toString(), result.stdout.toString())) {
      throw AdbException(
        'Cannot access "$packageName": app must be debuggable (debug build). '
        'Release builds cannot use run-as.\n'
        '${result.stderr.toString().trim()}',
      );
    }
    throw AdbException(
      'Failed to list databases (exit ${result.exitCode}).\n'
      'stderr: ${result.stderr}\nstdout: ${result.stdout}',
    );
  }

  Future<String> pullDatabase(
    String serial,
    String packageName,
    String remoteDbPath,
    String localDir,
  ) async {
    try {
      final adb = await findAdb();
      final baseName = p.basename(remoteDbPath);
      final localMain = p.join(localDir, baseName);

      await Directory(localDir).create(recursive: true);
      await _pullOneFile(adb, serial, packageName, remoteDbPath, localMain);

      final lower = remoteDbPath.toLowerCase();
      if (lower.endsWith('.db') ||
          lower.endsWith('.sqlite') ||
          lower.endsWith('.sqlite3') ||
          lower.contains('.db.')) {
        for (final suffix in <String>['-wal', '-shm']) {
          final companionRemote = '$remoteDbPath$suffix';
          final localCompanion = p.join(localDir, '$baseName$suffix');
          await _pullOptionalCompanion(
            adb,
            serial,
            packageName,
            companionRemote,
            localCompanion,
          );
        }
      }

      return localMain;
    } catch (e, st) {
      developer.log(
        'pullDatabase failed for $remoteDbPath',
        name: 'AdbService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> _pullOneFile(
    String adb,
    String serial,
    String packageName,
    String remotePath,
    String localPath,
  ) async {
    final result = await Process.run(
      adb,
      ['-s', serial, 'exec-out', 'run-as $packageName cat $remotePath'],
      stdoutEncoding: null,
      stderrEncoding: systemEncoding,
    );

    if (result.exitCode != 0) {
      throw AdbException('Failed to read $remotePath:\n${result.stderr}');
    }

    final bytes = result.stdout as List<int>;
    if (bytes.isEmpty) {
      throw AdbException('Empty file from device: $remotePath');
    }

    await File(localPath).writeAsBytes(bytes, flush: true);
  }

  Future<void> _pullOptionalCompanion(
    String adb,
    String serial,
    String packageName,
    String remotePath,
    String localPath,
  ) async {
    final result = await Process.run(
      adb,
      ['-s', serial, 'exec-out', 'run-as $packageName cat $remotePath'],
      stdoutEncoding: null,
      stderrEncoding: systemEncoding,
    );
    if (result.exitCode != 0) return;
    final bytes = result.stdout as List<int>;
    if (bytes.isEmpty) return;
    await File(localPath).writeAsBytes(bytes, flush: true);
  }
}

class AdbException implements Exception {
  AdbException(this.message);
  final String message;

  @override
  String toString() => message;
}
