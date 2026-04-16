import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/simulator_device.dart';
import '../services/ios_simulator_service.dart';

final iosSimulatorServiceProvider = Provider<IosSimulatorService>(
  (ref) => IosSimulatorService(),
);

final simulatorsRefreshingProvider =
    NotifierProvider<SimulatorsRefreshingNotifier, bool>(
      SimulatorsRefreshingNotifier.new,
    );

class SimulatorsRefreshingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
}

final simulatorsProvider =
    AsyncNotifierProvider<SimulatorsNotifier, List<IosSimulatorDevice>>(
      SimulatorsNotifier.new,
    );

class SimulatorsNotifier extends AsyncNotifier<List<IosSimulatorDevice>> {
  @override
  Future<List<IosSimulatorDevice>> build() async {
    final svc = ref.read(iosSimulatorServiceProvider);
    if (!svc.isSupportedHost) return const [];
    return svc.listDevices();
  }

  Future<void> refresh() async {
    ref.read(simulatorsRefreshingProvider.notifier).state = true;
    try {
      final svc = ref.read(iosSimulatorServiceProvider);
      if (!svc.isSupportedHost) {
        state = const AsyncData([]);
        return;
      }
      final list = await svc.listDevices();
      state = AsyncData(list);
    } catch (e, st) {
      state = AsyncError(e, st);
    } finally {
      ref.read(simulatorsRefreshingProvider.notifier).state = false;
    }
  }
}
