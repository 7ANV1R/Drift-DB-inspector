enum ConnectBackend {
  /// Android device / emulator via `adb`.
  adb,

  /// iOS Simulator on this Mac (`simctl` + host filesystem). macOS host only.
  iosSimulator,

  /// User-picked `.db` / `.sqlite` file on disk (read-only).
  localFile,
}
