import 'package:path/path.dart' as p;

import '../../models/connect_backend.dart';

String connectSubtitle(ConnectBackend backend) {
  switch (backend) {
    case ConnectBackend.adb:
      return 'Android: USB or emulator, then pull a copy to this Mac.';
    case ConnectBackend.iosSimulator:
      return 'iOS Simulator: pick a simulator and bundle ID; files read from this Mac.';
    case ConnectBackend.localFile:
      return 'Open a .db or .sqlite file from disk (read-only).';
  }
}

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
