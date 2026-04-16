import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/device.dart';
import '../services/adb_service.dart';

final adbServiceProvider = Provider<AdbService>((ref) => AdbService());

/// True while [DevicesNotifier.refresh] is in flight (no [AsyncLoading] — avoids UI blink).
final devicesRefreshingProvider =
    NotifierProvider<DevicesRefreshingNotifier, bool>(
      DevicesRefreshingNotifier.new,
    );

class DevicesRefreshingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
}

final devicesProvider = AsyncNotifierProvider<DevicesNotifier, List<AdbDevice>>(
  DevicesNotifier.new,
);

class DevicesNotifier extends AsyncNotifier<List<AdbDevice>> {
  @override
  Future<List<AdbDevice>> build() async {
    if (Platform.isIOS || Platform.isAndroid) {
      return const [];
    }
    final adb = ref.read(adbServiceProvider);
    return adb.listDevices();
  }

  Future<void> refresh() async {
    ref.read(devicesRefreshingProvider.notifier).state = true;
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        state = const AsyncData([]);
        return;
      }
      final adb = ref.read(adbServiceProvider);
      final list = await adb.listDevices();
      state = AsyncData(list);
    } catch (e, st) {
      state = AsyncError(e, st);
    } finally {
      ref.read(devicesRefreshingProvider.notifier).state = false;
    }
  }
}
