/// One row from `xcrun simctl list devices available -j`.
class IosSimulatorDevice {
  const IosSimulatorDevice({
    required this.udid,
    required this.name,
    required this.state,
    required this.runtime,
  });

  final String udid;
  final String name;
  final String state;
  final String runtime;

  bool get isBooted => state.toLowerCase() == 'booted';

  /// Readable primary line (device type name + boot hint).
  String get displayTitle => isBooted ? '$name · Booted' : name;

  /// Short runtime label (last part of CoreSimulator runtime id).
  String get runtimeShort {
    final i = runtime.lastIndexOf('.');
    if (i >= 0 && i + 1 < runtime.length) {
      return runtime.substring(i + 1).replaceAll('-', ' ');
    }
    return runtime;
  }

  @override
  String toString() => 'IosSimulatorDevice($name, $udid)';
}
