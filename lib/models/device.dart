/// Represents a device listed by `adb devices`.
class AdbDevice {
  const AdbDevice({required this.serial, this.model, required this.state});

  final String serial;
  final String? model;
  final String state;

  bool get isReady => state == 'device';

  String get displayLabel {
    if (model != null && model!.isNotEmpty) {
      return '$model ($serial)';
    }
    return serial;
  }

  @override
  String toString() => 'AdbDevice($serial, state=$state)';
}
