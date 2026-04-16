import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:macos_window_utils/macos_window_utils.dart';

/// Space reserved for 🔴🟡🟢 so this overlay does not steal their clicks.
const double kMacosTrafficLightsWidth = 76;

/// Double-click the title-bar region (right of traffic lights) toggles window
/// zoom to the screen’s standard maximized frame (same idea as the green
/// button), for when Flutter draws under the title bar.
class MacosTitleBarZoomWrapper extends StatefulWidget {
  const MacosTitleBarZoomWrapper({
    super.key,
    required this.title,
    required this.child,
  });

  /// Centered in the title-bar strip (e.g. app name or `bundle · file`).
  final String title;

  final Widget child;

  @override
  State<MacosTitleBarZoomWrapper> createState() =>
      _MacosTitleBarZoomWrapperState();
}

class _MacosTitleBarZoomWrapperState extends State<MacosTitleBarZoomWrapper> {
  double _titlebarHeight = 0;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _updateTitlebarHeight());
    }
  }

  Future<void> _updateTitlebarHeight() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) return;
    final h = await WindowManipulator.getTitlebarHeight();
    if (!mounted || h <= 0) return;
    setState(() => _titlebarHeight = h);
  }

  Future<void> _toggleZoom() async {
    final zoomed = await WindowManipulator.isWindowZoomed();
    if (!mounted) return;
    if (zoomed) {
      await WindowManipulator.unzoomWindow();
    } else {
      await WindowManipulator.zoomWindow();
    }
    await _updateTitlebarHeight();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return widget.child;
    }

    final safe = TitlebarSafeArea(child: widget.child);
    if (_titlebarHeight <= 0) {
      return safe;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        safe,
        Positioned(
          left: kMacosTrafficLightsWidth,
          top: 0,
          right: 0,
          height: _titlebarHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTap: () => unawaited(_toggleZoom()),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
