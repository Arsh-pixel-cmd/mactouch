/// Display information model for MacTouch.
///
/// Represents a physical display with its logical bounds, scale factor,
/// and capability status. Values come from platform adapters and may be
/// unavailable or estimated.
library;

import '../core/coordinates/coordinate_spaces.dart';

/// Status of a display info value.
enum DisplayValueStatus {
  /// Value was read from the OS and is considered reliable.
  reported,

  /// Value is estimated or derived (e.g., default scale factor).
  estimated,

  /// Value could not be determined.
  unavailable,
}

/// Information about a connected display.
class DisplayInfo {
  /// Stable identifier for this display, if available from the platform.
  /// May be null on platforms that don't expose stable IDs.
  final String? id;

  /// Human-readable name or description.
  final String name;

  /// Logical desktop bounds (position and size in desktop-global coordinates).
  /// Origin may be negative for non-primary displays.
  final DisplayBounds bounds;

  /// Scale factor (logical points to physical pixels).
  /// 1.0 for standard displays, 2.0 for Retina/HiDPI.
  final double scaleFactor;

  /// Whether this is the primary display.
  final bool isPrimary;

  /// How reliable the bounds value is.
  final DisplayValueStatus boundsStatus;

  /// How reliable the scale factor value is.
  final DisplayValueStatus scaleStatus;

  const DisplayInfo({
    this.id,
    required this.name,
    required this.bounds,
    this.scaleFactor = 1.0,
    this.isPrimary = false,
    this.boundsStatus = DisplayValueStatus.reported,
    this.scaleStatus = DisplayValueStatus.reported,
  });

  /// Physical pixel dimensions (logical * scale).
  ({double width, double height}) get physicalSize => (
        width: bounds.width * scaleFactor,
        height: bounds.height * scaleFactor,
      );

  /// A display with valid, reported bounds.
  bool get isFullySupported =>
      bounds.isValid && boundsStatus == DisplayValueStatus.reported;

  @override
  String toString() =>
      'DisplayInfo($name, bounds: $bounds, scale: $scaleFactor, '
      'primary: $isPrimary, boundsStatus: $boundsStatus)';
}
