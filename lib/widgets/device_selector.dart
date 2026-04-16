import 'package:flutter/material.dart';

import '../models/device.dart';

class DeviceSelector extends StatelessWidget {
  const DeviceSelector({
    super.key,
    required this.devices,
    required this.selectedSerial,
    required this.onChanged,
    required this.onRefresh,
    this.busy = false,
  });

  final List<AdbDevice> devices;
  final String? selectedSerial;
  final ValueChanged<String?> onChanged;
  final VoidCallback onRefresh;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = devices.where((d) => d.isReady).toList();
    return Row(
      children: [
        Expanded(
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Device',
              prefixIcon: Icon(Icons.smartphone_outlined, size: 22),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                isDense: true,
                borderRadius: BorderRadius.circular(14),
                value:
                    selectedSerial != null &&
                        ready.any((d) => d.serial == selectedSerial)
                    ? selectedSerial
                    : null,
                hint: Text(
                  ready.isEmpty
                      ? 'Connect a device via USB / ADB'
                      : 'Choose device',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                items: ready
                    .map(
                      (d) => DropdownMenuItem(
                        value: d.serial,
                        child: Text(
                          d.displayLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: busy ? null : onChanged,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Refresh device list',
          onPressed: busy ? null : onRefresh,
          icon: busy
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              : const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}
