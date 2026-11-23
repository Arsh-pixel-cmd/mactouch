/// Quadrant and rectangular region model for MacTouch.
///
/// Quadrant layout (in normalized coordinates):
/// ```
///   Q1 (top-left)     |  Q2 (top-right)
///   u ∈ [0, 0.5)      |  u ∈ [0.5, 1]
///   v ∈ [0, 0.5)      |  v ∈ [0, 0.5)
///   --------------------|--------------------
///   Q3 (bottom-left)  |  Q4 (bottom-right)
///   u ∈ [0, 0.5)      |  u ∈ [0.5, 1]
///   v ∈ [0.5, 1]      |  v ∈ [0.5, 1]
/// ```
///
/// **Boundary ownership**: Points exactly on the midpoint (u = 0.5 or v = 0.5)
/// belong to the right/bottom quadrant. This means:
/// - u < 0.5 → left column; u >= 0.5 → right column
/// - v < 0.5 → top row; v >= 0.5 → bottom row
///
/// This convention is deterministic and consistent: the split point always
/// belongs to the higher-index quadrant.
library;

import '../coordinates/coordinate_spaces.dart';

/// One of four quadrants in a normalized coordinate display.
enum Quadrant {
  /// Top-left: u ∈ [0, 0.5), v ∈ [0, 0.5).
  topLeft(1, 'Top-Left'),

  /// Top-right: u ∈ [0.5, 1], v ∈ [0, 0.5).
  topRight(2, 'Top-Right'),

  /// Bottom-left: u ∈ [0, 0.5), v ∈ [0.5, 1].
  bottomLeft(3, 'Bottom-Left'),

  /// Bottom-right: u ∈ [0.5, 1], v ∈ [0.5, 1].
  bottomRight(4, 'Bottom-Right');

  /// Quadrant number (1-4), following standard mathematical/display convention.
  final int number;

  /// Human-readable label.
  final String label;

  const Quadrant(this.number, this.label);
}

/// Determines which quadrant a normalized point belongs to.
///
/// **Boundary ownership**: u = 0.5 belongs to the right column;
/// v = 0.5 belongs to the bottom row.
///
/// Returns `null` if the point is out of the normalized [0, 1] range.
Quadrant? getQuadrant(NormalizedPoint point) {
  if (!point.isInBounds) return null;

  final isRight = point.u >= 0.5;
  final isBottom = point.v >= 0.5;

  if (!isRight && !isBottom) return Quadrant.topLeft;
  if (isRight && !isBottom) return Quadrant.topRight;
  if (!isRight && isBottom) return Quadrant.bottomLeft;
  return Quadrant.bottomRight;
}

/// A named rectangular region within normalized coordinate space.
///
/// Boundaries are inclusive on all sides. Use [contains] to test membership.
class Region {
  /// Human-readable name for this region.
  final String name;

  /// Left edge in normalized coordinates.
  final double uMin;

  /// Right edge in normalized coordinates.
  final double uMax;

  /// Top edge in normalized coordinates.
  final double vMin;

  /// Bottom edge in normalized coordinates.
  final double vMax;

  const Region({
    required this.name,
    required this.uMin,
    required this.uMax,
    required this.vMin,
    required this.vMax,
  });

  /// Whether the point is inside this region (inclusive on all sides).
  bool contains(NormalizedPoint point) =>
      point.u >= uMin &&
      point.u <= uMax &&
      point.v >= vMin &&
      point.v <= vMax;

  @override
  String toString() =>
      'Region($name, u: [$uMin, $uMax], v: [$vMin, $vMax])';
}

/// A set of regions that can be queried by point.
///
/// Regions may overlap; [regionsContaining] returns all matching regions.
class RegionMap {
  final List<Region> _regions;

  const RegionMap(this._regions);

  /// All regions containing the given normalized point.
  List<Region> regionsContaining(NormalizedPoint point) =>
      _regions.where((r) => r.contains(point)).toList();

  /// The first region containing the point, or null.
  Region? firstContaining(NormalizedPoint point) {
    for (final r in _regions) {
      if (r.contains(point)) return r;
    }
    return null;
  }

  /// Number of regions.
  int get length => _regions.length;
}
