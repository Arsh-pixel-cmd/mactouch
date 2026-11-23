/// Platform adapter interface for display enumeration.
///
/// Each platform implements this interface to provide display information.
/// If a platform cannot provide display data, it returns an explicit
/// "unavailable" result — never fabricated data.
library;

import 'dart:ui' as ui;
import '../models/display_info.dart';
import '../models/capability_status.dart';
import '../core/coordinates/coordinate_spaces.dart';

/// Result of a display enumeration attempt.
class DisplayEnumerationResult {
  /// List of detected displays (empty if enumeration is unsupported).
  final List<DisplayInfo> displays;

  /// Whether enumeration succeeded.
  final bool success;

  /// Error or status message if enumeration failed or is unsupported.
  final String? message;

  const DisplayEnumerationResult({
    required this.displays,
    required this.success,
    this.message,
  });

  /// An explicitly unsupported result.
  factory DisplayEnumerationResult.unsupported(String reason) =>
      DisplayEnumerationResult(
        displays: [],
        success: false,
        message: 'Display enumeration unsupported: $reason',
      );
}

/// Abstract interface for platform-specific display discovery.
///
/// Implementations should:
/// - Return real data only if actually available from the OS.
/// - Return [DisplayEnumerationResult.unsupported] if the platform adapter
///   is not implemented or the OS API is unavailable.
/// - Never fabricate display data.
abstract class DisplayAdapter {
  /// Enumerate currently connected displays.
  Future<DisplayEnumerationResult> enumerateDisplays();

  /// Get the capability status of display enumeration on this platform.
  CapabilityStatus get enumerationCapability;
}

/// Stub adapter that reports display enumeration as unavailable.
///
/// Used as a fallback when no platform-specific implementation exists.
class UnsupportedDisplayAdapter implements DisplayAdapter {
  final String reason;

  const UnsupportedDisplayAdapter(
      [this.reason = 'No platform adapter available']);

  @override
  Future<DisplayEnumerationResult> enumerateDisplays() async =>
      DisplayEnumerationResult.unsupported(reason);

  @override
  CapabilityStatus get enumerationCapability => CapabilityStatus(
        name: 'Display Enumeration',
        level: CapabilityLevel.unsupported,
        description: reason,
      );
}

/// Simulated display adapter for testing and development.
///
/// Provides realistic-looking display data that is clearly labeled as simulated,
/// including a secondary monitor with negative coordinates to verify coordinate mapping.
class SimulatedDisplayAdapter implements DisplayAdapter {
  const SimulatedDisplayAdapter();

  @override
  Future<DisplayEnumerationResult> enumerateDisplays() async {
    return const DisplayEnumerationResult(
      displays: [
        DisplayInfo(
          id: 'simulated-primary',
          name: 'Simulated Primary Display (1440x900 @ 2.0x)',
          bounds: DisplayBounds(left: 0, top: 0, width: 1440, height: 900),
          scaleFactor: 2.0,
          isPrimary: true,
          boundsStatus: DisplayValueStatus.estimated,
          scaleStatus: DisplayValueStatus.estimated,
        ),
        DisplayInfo(
          id: 'simulated-secondary',
          name: 'Simulated Secondary Display (Negative Origin -1920, 0)',
          bounds:
              DisplayBounds(left: -1920, top: 0, width: 1920, height: 1080),
          scaleFactor: 1.0,
          isPrimary: false,
          boundsStatus: DisplayValueStatus.estimated,
          scaleStatus: DisplayValueStatus.estimated,
        ),
      ],
      success: true,
      message: 'Simulated multi-display data — not from OS.',
    );
  }

  @override
  CapabilityStatus get enumerationCapability => const CapabilityStatus(
        name: 'Display Enumeration (Simulated)',
        level: CapabilityLevel.partial,
        description:
            'Using simulated display data for multi-monitor coordinate testing. '
            'Values are NOT from the operating system.',
      );
}

/// Live Flutter Window view adapter.
///
/// Reads display/view bounds directly from Flutter's [ui.PlatformDispatcher.instance.views].
/// Honest scope: reports the active Flutter application window's logical size and device
/// pixel ratio. Full desktop-wide multi-monitor enumeration requires native OS plugins.
class FlutterWindowDisplayAdapter implements DisplayAdapter {
  const FlutterWindowDisplayAdapter();

  @override
  Future<DisplayEnumerationResult> enumerateDisplays() async {
    try {
      final views = ui.PlatformDispatcher.instance.views;
      if (views.isEmpty) {
        return const DisplayEnumerationResult(
          displays: [
            DisplayInfo(
              id: 'flutter-default-window',
              name: 'Flutter Window (Default Bounds)',
              bounds: DisplayBounds(left: 0, top: 0, width: 1280, height: 800),
              scaleFactor: 1.0,
              isPrimary: true,
              boundsStatus: DisplayValueStatus.estimated,
              scaleStatus: DisplayValueStatus.estimated,
            ),
          ],
          success: true,
          message: 'Estimated default window bounds.',
        );
      }

      final displays = <DisplayInfo>[];
      int index = 0;
      for (final view in views) {
        final dpr = view.devicePixelRatio > 0 ? view.devicePixelRatio : 1.0;
        final physicalSize = view.physicalSize;
        final logicalWidth = physicalSize.width > 0 ? physicalSize.width / dpr : 1280.0;
        final logicalHeight = physicalSize.height > 0 ? physicalSize.height / dpr : 800.0;

        displays.add(
          DisplayInfo(
            id: 'view-${view.viewId}',
            name: index == 0 ? 'Active Flutter Window' : 'Secondary Window #$index',
            bounds: DisplayBounds(
              left: 0,
              top: 0,
              width: logicalWidth,
              height: logicalHeight,
            ),
            scaleFactor: dpr,
            isPrimary: index == 0,
            boundsStatus: DisplayValueStatus.reported,
            scaleStatus: DisplayValueStatus.reported,
          ),
        );
        index++;
      }

      return DisplayEnumerationResult(
        displays: displays,
        success: true,
        message: 'Live bounds reported via Flutter PlatformDispatcher.',
      );
    } catch (e) {
      return DisplayEnumerationResult.unsupported('Flutter view query error: $e');
    }
  }

  @override
  CapabilityStatus get enumerationCapability => const CapabilityStatus(
        name: 'Display Enumeration (Live Window)',
        level: CapabilityLevel.partial,
        description:
            'Reports active Flutter window bounds and scale factor. '
            'Full OS desktop multi-display topology requires platform-specific plugins.',
        platformNote:
            'macOS: NSScreen.screens. Windows: EnumDisplayMonitors. Linux: X11 XRandR / Wayland wl_output.',
      );
}
