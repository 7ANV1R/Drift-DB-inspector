import 'package:path/path.dart' as p;

bool pathLooksLikeSqlite(String path) {
  final n = p.basename(path).toLowerCase();
  if (n.endsWith('-journal') || n.endsWith('-wal') || n.endsWith('-shm')) {
    return false;
  }
  return RegExp(
    r'\.(sqlite3?|db)$',
    caseSensitive: false,
  ).hasMatch(n);
}

String formatConnectError(Object e) {
  var s = e.toString();
  for (final prefix in [
    'AdbException: ',
    'SimulatorException: ',
    'StateError: ',
    'Exception: ',
  ]) {
    if (s.startsWith(prefix)) {
      s = s.substring(prefix.length);
      break;
    }
  }
  return s;
}
