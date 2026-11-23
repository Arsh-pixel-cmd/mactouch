/// Coordinate space types and conversions for MacTouch.
///
/// Named coordinate spaces:
/// - **Logical points**: The OS-reported coordinate system (may differ from
///   physical pixels by a scale factor). Used by Flutter layout.
/// - **Physical pixels**: Actual device pixels. `physical = logical * scaleFactor`.
/// - **Normalized coordinates**: Values in [0, 1] relative to a display's
///   logical bounds. `u = (x - left) / width`, `v = (y - top) / height`.
/// - **Desktop-global coordinates**: Logical points in the full desktop
///   coordinate space, which may span multiple displays and include negative
///   origins for non-primary monitors.
library;

/// A point in a named coordinate space.
///
/// The [space] field documents which coordinate space this point belongs to.
/// This prevents accidental mixing of different coordinate systems.
class CoordinatePoint {
  /// X component (horizontal).
  final double x;

  /// Y component (vertical).
  final double y;

  /// The coordinate space this point belongs to.
  final CoordinateSpace space;

  const CoordinatePoint(this.x, this.y, this.space);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoordinatePoint &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          space == other.space;

  @override
  int get hashCode => Object.hash(x, y, space);

  @override
  String toString() => 'CoordinatePoint($x, $y, space: $space)';
}

/// Identifies a coordinate space to prevent implicit mixing.
enum CoordinateSpace {
  /// OS-reported logical points.
  logicalPoints,

  /// Device physical pixels.
  physicalPixels,

  /// Normalized [0, 1] relative to a display's logical bounds.
  normalized,

  /// Desktop-global logical coordinates (may be negative for secondary displays).
  desktopGlobal,
}

/// Represents normalized coordinates in [0, 1] (or out-of-bounds if unclamped).
///
/// Normalization is relative to a specific display's logical bounds.
class NormalizedPoint {
  /// Horizontal normalized coordinate. In-bounds: [0, 1].
  final double u;

  /// Vertical normalized coordinate. In-bounds: [0, 1].
  final double v;

  const NormalizedPoint(this.u, this.v);

  /// Whether both u and v are within [0, 1] inclusive.
  bool get isInBounds => u >= 0.0 && u <= 1.0 && v >= 0.0 && v <= 1.0;

  /// Returns a clamped copy with u and v in [0, 1].
  NormalizedPoint clamped() => NormalizedPoint(
        u.clamp(0.0, 1.0),
        v.clamp(0.0, 1.0),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NormalizedPoint &&
          runtimeType == other.runtimeType &&
          u == other.u &&
          v == other.v;

  @override
  int get hashCode => Object.hash(u, v);

  @override
  String toString() => 'NormalizedPoint(u: $u, v: $v)';
}

/// Logical display bounds in desktop-global coordinates.
///
/// A display's origin can be negative (e.g., a secondary monitor to the left of
/// the primary). Width and height must be positive for valid bounds.
class DisplayBounds {
  /// Left edge in desktop-global logical points.
  final double left;

  /// Top edge in desktop-global logical points.
  final double top;

  /// Width in logical points. Must be > 0 for valid bounds.
  final double width;

  /// Height in logical points. Must be > 0 for valid bounds.
  final double height;

  const DisplayBounds({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// Right edge (left + width).
  double get right => left + width;

  /// Bottom edge (top + height).
  double get bottom => top + height;

  /// Whether width and height are both positive (non-zero, non-negative).
  bool get isValid => width > 0 && height > 0;

  /// Whether [point] (in desktop-global coordinates) is within these bounds.
  bool contains(double x, double y) =>
      x >= left && x <= right && y >= top && y <= bottom;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisplayBounds &&
          runtimeType == other.runtimeType &&
          left == other.left &&
          top == other.top &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() =>
      'DisplayBounds(left: $left, top: $top, ${width}x$height)';
}

/// Converts between desktop-global logical coordinates and normalized
/// coordinates relative to a [DisplayBounds].
class CoordinateMapper {
  final DisplayBounds bounds;

  const CoordinateMapper(this.bounds);

  /// Convert a desktop-global point to normalized coordinates.
  ///
  /// Returns raw normalized values (may be outside [0, 1] if the point is
  /// outside the display bounds). Use [NormalizedPoint.clamped] if you need
  /// clamped output for mapping into the display.
  ///
  /// Throws [ArgumentError] if bounds are invalid (zero or negative dimensions).
  NormalizedPoint toNormalized(double x, double y) {
    if (!bounds.isValid) {
      throw ArgumentError(
          'Cannot normalize with invalid bounds: $bounds');
    }
    final u = (x - bounds.left) / bounds.width;
    final v = (y - bounds.top) / bounds.height;
    return NormalizedPoint(u, v);
  }

  /// Convert normalized coordinates back to desktop-global logical points.
  ///
  /// Throws [ArgumentError] if bounds are invalid.
  CoordinatePoint fromNormalized(NormalizedPoint normalized) {
    if (!bounds.isValid) {
      throw ArgumentError(
          'Cannot denormalize with invalid bounds: $bounds');
    }
    final x = normalized.u * bounds.width + bounds.left;
    final y = normalized.v * bounds.height + bounds.top;
    return CoordinatePoint(x, y, CoordinateSpace.desktopGlobal);
  }

  /// Convert a desktop-global point to normalized coordinates, clamped to [0, 1].
  ///
  /// Use this when mapping a point into a display's coordinate space
  /// (e.g., for rendering a simulated pointer).
  NormalizedPoint toNormalizedClamped(double x, double y) {
    return toNormalized(x, y).clamped();
  }
}
