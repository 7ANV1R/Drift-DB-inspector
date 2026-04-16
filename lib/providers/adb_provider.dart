import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/device.dart';
import '../services/adb_service.dart';

final adbServiceProvider = Provider<AdbService>((ref) => AdbService());

final devicesProvider = AsyncNotifierProvider<DevicesNotifier, List<AdbDevice>>(
  DevicesNotifier.new,
);

class DevicesNotifier extends AsyncNotifier<List<AdbDevice>> {
  @override
  Future<List<AdbDevice>> build() async {
    final adb = ref.read(adbServiceProvider);
    return adb.listDevices();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final adb = ref.read(adbServiceProvider);
      return adb.listDevices();
    });
  }
}
