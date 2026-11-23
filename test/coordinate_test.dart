import 'package:flutter_test/flutter_test.dart';
import 'package:mactouch/core/coordinates/coordinate_spaces.dart';
import 'package:mactouch/core/regions/quadrant.dart';

void main() {
  group('Coordinate Spaces & Normalization', () {
    test('Standard display origin at (0, 0)', () {
      const bounds = DisplayBounds(left: 0, top: 0, width: 1920, height: 1080);
      const mapper = CoordinateMapper(bounds);

      // Center
      final center = mapper.toNormalized(960, 540);
      expect(center.u, closeTo(0.5, 1e-6));
      expect(center.v, closeTo(0.5, 1e-6));
      expect(center.isInBounds, isTrue);

      // Top-left
      final origin = mapper.toNormalized(0, 0);
      expect(origin.u, closeTo(0.0, 1e-6));
      expect(origin.v, closeTo(0.0, 1e-6));

      // Bottom-right
      final br = mapper.toNormalized(1920, 1080);
      expect(br.u, closeTo(1.0, 1e-6));
      expect(br.v, closeTo(1.0, 1e-6));

      // Round trip back to desktop global
      final pt = mapper.fromNormalized(const NormalizedPoint(0.25, 0.75));
      expect(pt.x, closeTo(480, 1e-6));
      expect(pt.y, closeTo(810, 1e-6));
      expect(pt.space, CoordinateSpace.desktopGlobal);
    });

    test('Secondary display with negative desktop origin', () {
      // Secondary monitor placed to the left: left = -1920, top = -100
      const bounds = DisplayBounds(left: -1920, top: -100, width: 1920, height: 1080);
      const mapper = CoordinateMapper(bounds);

      // Top-left of secondary display is at (-1920, -100)
      final topLeft = mapper.toNormalized(-1920, -100);
      expect(topLeft.u, closeTo(0.0, 1e-6));
      expect(topLeft.v, closeTo(0.0, 1e-6));
      expect(topLeft.isInBounds, isTrue);

      // Center of secondary display
      final center = mapper.toNormalized(-960, 440);
      expect(center.u, closeTo(0.5, 1e-6));
      expect(center.v, closeTo(0.5, 1e-6));

      // Round trip from normalized back to negative origin
      final restored = mapper.fromNormalized(const NormalizedPoint(0.0, 0.0));
      expect(restored.x, closeTo(-1920, 1e-6));
      expect(restored.y, closeTo(-100, 1e-6));
    });

    test('Out-of-bounds points and clamping behavior', () {
      const bounds = DisplayBounds(left: 0, top: 0, width: 1000, height: 1000);
      const mapper = CoordinateMapper(bounds);

      // Point outside bounds to the left and below
      final outPoint = mapper.toNormalized(-200, 1500);
      expect(outPoint.u, closeTo(-0.2, 1e-6));
      expect(outPoint.v, closeTo(1.5, 1e-6));
      expect(outPoint.isInBounds, isFalse);

      // Clamped point
      final clamped = mapper.toNormalizedClamped(-200, 1500);
      expect(clamped.u, closeTo(0.0, 1e-6));
      expect(clamped.v, closeTo(1.0, 1e-6));
      expect(clamped.isInBounds, isTrue);
    });

    test('Invalid bounds handling', () {
      // Zero width
      const zeroWidth = DisplayBounds(left: 0, top: 0, width: 0, height: 1000);
      expect(zeroWidth.isValid, isFalse);
      const mapperZero = CoordinateMapper(zeroWidth);
      expect(() => mapperZero.toNormalized(50, 50), throwsArgumentError);
      expect(() => mapperZero.fromNormalized(const NormalizedPoint(0.5, 0.5)), throwsArgumentError);

      // Negative height
      const negHeight = DisplayBounds(left: 0, top: 0, width: 1000, height: -100);
      expect(negHeight.isValid, isFalse);
      const mapperNeg = CoordinateMapper(negHeight);
      expect(() => mapperNeg.toNormalized(50, 50), throwsArgumentError);
    });
  });

  group('Quadrant Boundary Ownership & Regions', () {
    test('Boundary convention: midpoints belong to Q2/Q3/Q4', () {
      // (0.5, 0.5) is exact center intersection -> belongs to Q4 (bottom-right)
      expect(getQuadrant(const NormalizedPoint(0.5, 0.5)), Quadrant.bottomRight);

      // (0.5, 0.2) is vertical midpoint on top half -> belongs to Q2 (top-right)
      expect(getQuadrant(const NormalizedPoint(0.5, 0.2)), Quadrant.topRight);

      // (0.2, 0.5) is horizontal midpoint on left half -> belongs to Q3 (bottom-left)
      expect(getQuadrant(const NormalizedPoint(0.2, 0.5)), Quadrant.bottomLeft);

      // Interior of Q1
      expect(getQuadrant(const NormalizedPoint(0.25, 0.25)), Quadrant.topLeft);

      // Interior of Q2
      expect(getQuadrant(const NormalizedPoint(0.75, 0.25)), Quadrant.topRight);

      // Interior of Q3
      expect(getQuadrant(const NormalizedPoint(0.25, 0.75)), Quadrant.bottomLeft);

      // Interior of Q4
      expect(getQuadrant(const NormalizedPoint(0.75, 0.75)), Quadrant.bottomRight);
    });

    test('Corners boundary ownership', () {
      expect(getQuadrant(const NormalizedPoint(0.0, 0.0)), Quadrant.topLeft);
      expect(getQuadrant(const NormalizedPoint(1.0, 0.0)), Quadrant.topRight);
      expect(getQuadrant(const NormalizedPoint(0.0, 1.0)), Quadrant.bottomLeft);
      expect(getQuadrant(const NormalizedPoint(1.0, 1.0)), Quadrant.bottomRight);
    });

    test('Out-of-bounds normalized point returns null quadrant', () {
      expect(getQuadrant(const NormalizedPoint(-0.01, 0.5)), isNull);
      expect(getQuadrant(const NormalizedPoint(1.01, 0.5)), isNull);
      expect(getQuadrant(const NormalizedPoint(0.5, -0.01)), isNull);
      expect(getQuadrant(const NormalizedPoint(0.5, 1.01)), isNull);
    });

    test('Custom Region & RegionMap membership', () {
      const targetRegion = Region(
        name: 'CenterTarget',
        uMin: 0.4,
        uMax: 0.6,
        vMin: 0.4,
        vMax: 0.6,
      );
      const map = RegionMap([targetRegion]);

      expect(targetRegion.contains(const NormalizedPoint(0.5, 0.5)), isTrue);
      expect(targetRegion.contains(const NormalizedPoint(0.4, 0.6)), isTrue); // inclusive bounds
      expect(targetRegion.contains(const NormalizedPoint(0.39, 0.5)), isFalse);
      expect(map.regionsContaining(const NormalizedPoint(0.5, 0.5)).length, 1);
      expect(map.firstContaining(const NormalizedPoint(0.1, 0.1)), isNull);
    });
  });
}
