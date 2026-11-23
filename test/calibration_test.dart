import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mactouch/core/calibration/affine_calibration.dart';
import 'package:mactouch/models/calibration_profile.dart';
import 'package:mactouch/services/profile_store.dart';

void main() {
  group('Affine Calibration Engine', () {
    final calibrator = AffineCalibrator();

    test('Exactly 3 non-collinear samples gives zero residual error', () {
      // Pure identity transform plus offset: x' = 2x + 10, y' = 3y + 20
      // a=2, b=0, c=10, d=0, e=3, f=20
      final samples = [
        const CalibrationSample(sourceX: 0, sourceY: 0, destX: 10, destY: 20),
        const CalibrationSample(sourceX: 100, sourceY: 0, destX: 210, destY: 20),
        const CalibrationSample(sourceX: 0, sourceY: 100, destX: 10, destY: 320),
      ];

      final result = calibrator.calibrate(samples);
      expect(result.error, isNull);
      expect(result.result, isNotNull);

      final r = result.result!;
      expect(r.parameters[0], closeTo(2.0, 1e-6)); // a
      expect(r.parameters[1], closeTo(0.0, 1e-6)); // b
      expect(r.parameters[2], closeTo(10.0, 1e-6)); // c
      expect(r.parameters[3], closeTo(0.0, 1e-6)); // d
      expect(r.parameters[4], closeTo(3.0, 1e-6)); // e
      expect(r.parameters[5], closeTo(20.0, 1e-6)); // f

      // Zero residuals on exact triangle
      expect(r.rmsError, closeTo(0.0, 1e-6));
      expect(r.maxError, closeTo(0.0, 1e-6));
      expect(r.sampleCount, 3);

      // Verify transformation of arbitrary point
      final transformed = r.transform(50, 40);
      expect(transformed.x, closeTo(2 * 50 + 10, 1e-6));
      expect(transformed.y, closeTo(3 * 40 + 20, 1e-6));
    });

    test('Over-determined 4-corner calibration with noise produces least-squares fit', () {
      final samples = [
        const CalibrationSample(sourceX: 0, sourceY: 0, destX: 2, destY: -1),
        const CalibrationSample(sourceX: 1000, sourceY: 0, destX: 1001, destY: 1),
        const CalibrationSample(sourceX: 1000, sourceY: 800, destX: 999, destY: 802),
        const CalibrationSample(sourceX: 0, sourceY: 800, destX: 1, destY: 799),
      ];

      final result = calibrator.calibrate(samples);
      expect(result.error, isNull);
      expect(result.result, isNotNull);

      final r = result.result!;
      expect(r.sampleCount, 4);
      expect(r.rmsError, greaterThan(0.0));
      expect(r.rmsError, lessThan(3.0));
    });

    test('Rejects fewer than 3 samples', () {
      final samples = [
        const CalibrationSample(sourceX: 10, sourceY: 10, destX: 10, destY: 10),
        const CalibrationSample(sourceX: 20, sourceY: 20, destX: 20, destY: 20),
      ];

      final result = calibrator.calibrate(samples);
      expect(result.result, isNull);
      expect(result.error, contains('At least 3 non-collinear samples required'));
    });

    test('Rejects collinear samples (degenerate system)', () {
      // 3 collinear points along y = 2x
      final samples = [
        const CalibrationSample(sourceX: 10, sourceY: 20, destX: 11, destY: 21),
        const CalibrationSample(sourceX: 20, sourceY: 40, destX: 21, destY: 41),
        const CalibrationSample(sourceX: 30, sourceY: 60, destX: 31, destY: 61),
      ];

      final result = calibrator.calibrate(samples);
      expect(result.result, isNull);
      expect(result.error, contains('collinear'));
    });
  });

  group('Profile Serialization & Versioned JSON Store', () {
    test('CalibrationProfile round trip to JSON', () {
      const profile = CalibrationProfile(
        id: 'prof-test-1',
        name: 'Retina Display Calibration',
        displayId: 'disp-001',
        samples: [
          CalibrationSample(sourceX: 10, sourceY: 20, destX: 12, destY: 19),
          CalibrationSample(sourceX: 500, sourceY: 300, destX: 498, destY: 302),
        ],
        calibrationResult: AffineCalibrationResult(
          parameters: [1.0, 0.0, 2.0, 0.0, 1.0, -1.0],
          rmsError: 1.25,
          maxError: 2.1,
          sampleCount: 2,
        ),
        createdAt: '2026-11-23T12:00:00Z',
        modifiedAt: '2026-11-23T12:30:00Z',
      );

      final json = profile.toJson();
      final restored = CalibrationProfile.fromJson(json);

      expect(restored.id, profile.id);
      expect(restored.name, profile.name);
      expect(restored.displayId, profile.displayId);
      expect(restored.samples.length, 2);
      expect(restored.calibrationResult?.rmsError, closeTo(1.25, 1e-6));
      expect(restored.calibrationResult?.parameters, [1.0, 0.0, 2.0, 0.0, 1.0, -1.0]);
    });

    test('ProfileStoreDocument version check and serialization', () {
      const doc = ProfileStoreDocument(
        version: profileStoreVersion,
        profiles: [],
      );

      final encoded = jsonEncode(doc.toJson());
      final decodedJson = jsonDecode(encoded) as Map<String, dynamic>;
      final restoredDoc = ProfileStoreDocument.fromJson(decodedJson);

      expect(restoredDoc.version, 1);
      expect(restoredDoc.profiles, isEmpty);
    });
  });
}
