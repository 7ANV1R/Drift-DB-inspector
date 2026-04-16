/// Result of scanning the device for SQLite files under an app package.
class DatabaseDiscoveryResult {
  const DatabaseDiscoveryResult({required this.paths, required this.log});

  final List<String> paths;
  final String log;
}
