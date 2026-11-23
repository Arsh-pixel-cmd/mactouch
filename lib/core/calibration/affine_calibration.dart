/// Affine calibration transform for MacTouch.
///
/// An affine transform maps source coordinates to destination coordinates using:
///   x' = a * x + b * y + c
///   y' = d * x + e * y + f
///
/// This requires at least 3 non-collinear sample correspondences to solve.
/// More samples produce a least-squares fit.
///
/// **Important**: This performs a mathematical coordinate transformation.
/// It does NOT detect physical contact. Calibration samples in this MVP
/// are manually entered or simulated — not measured from a touch sensor.
library;

import 'dart:math' as math;

/// A pair of corresponding points: source (measured/simulated) and
/// destination (expected/target).
class CalibrationSample {
  /// Source coordinates (e.g., from a simulated pointer or manual entry).
  final double sourceX;
  final double sourceY;

  /// Destination coordinates (e.g., expected position on display).
  final double destX;
  final double destY;

  const CalibrationSample({
    required this.sourceX,
    required this.sourceY,
    required this.destX,
    required this.destY,
  });

  @override
  String toString() =>
      'CalibrationSample(($sourceX, $sourceY) -> ($destX, $destY))';
}

/// Result of computing an affine calibration.
class AffineCalibrationResult {
  /// The 6 affine parameters: [a, b, c, d, e, f]
  /// where x' = a*x + b*y + c, y' = d*x + e*y + f.
  final List<double> parameters;

  /// Root-mean-square residual error across all samples.
  final double rmsError;

  /// Maximum residual error across all samples.
  final double maxError;

  /// Number of samples used to compute this calibration.
  final int sampleCount;

  const AffineCalibrationResult({
    required this.parameters,
    required this.rmsError,
    required this.maxError,
    required this.sampleCount,
  });

  /// Transform a point using this calibration.
  ({double x, double y}) transform(double x, double y) {
    final a = parameters[0],
        b = parameters[1],
        c = parameters[2];
    final d = parameters[3],
        e = parameters[4],
        f = parameters[5];
    return (x: a * x + b * y + c, y: d * x + e * y + f);
  }

  @override
  String toString() =>
      'AffineCalibrationResult(params: $parameters, '
      'rmsError: ${rmsError.toStringAsFixed(4)}, '
      'maxError: ${maxError.toStringAsFixed(4)}, '
      'samples: $sampleCount)';
}

/// Computes an affine calibration from sample correspondences.
///
/// Requires at least 3 non-collinear samples. Returns an error message
/// if the input is degenerate.
class AffineCalibrator {
  /// Compute the affine transform from the given samples.
  ///
  /// Returns `null` with an error message if:
  /// - Fewer than 3 samples are provided
  /// - Samples are collinear (the system is degenerate)
  ({AffineCalibrationResult? result, String? error}) calibrate(
      List<CalibrationSample> samples) {
    if (samples.length < 3) {
      return (
        result: null,
        error:
            'At least 3 non-collinear samples required; got ${samples.length}.',
      );
    }

    // Check for collinearity of source points.
    if (_areCollinear(samples)) {
      return (
        result: null,
        error: 'Source points are collinear; cannot compute affine transform.',
      );
    }

    // Solve using least squares for the system:
    //   [x_i  y_i  1] * [a  d]^T = [x'_i  y'_i]
    //                    [b  e]
    //                    [c  f]
    //
    // We solve A * params_x = dest_x  and  A * params_y = dest_y
    // using the normal equations: A^T A * p = A^T b

    final n = samples.length;

    // Build A^T * A (3x3) and A^T * bx, A^T * by (3x1 each)
    double ata00 = 0, ata01 = 0, ata02 = 0;
    double ata11 = 0, ata12 = 0;
    double ata22 = 0;
    double atbx0 = 0, atbx1 = 0, atbx2 = 0;
    double atby0 = 0, atby1 = 0, atby2 = 0;

    for (final s in samples) {
      final x = s.sourceX, y = s.sourceY;
      final dx = s.destX, dy = s.destY;

      ata00 += x * x;
      ata01 += x * y;
      ata02 += x;
      ata11 += y * y;
      ata12 += y;
      ata22 += 1;

      atbx0 += x * dx;
      atbx1 += y * dx;
      atbx2 += dx;

      atby0 += x * dy;
      atby1 += y * dy;
      atby2 += dy;
    }

    // Solve 3x3 symmetric system using Cramer's rule
    // A^T A is symmetric: [[ata00, ata01, ata02], [ata01, ata11, ata12], [ata02, ata12, ata22]]
    final det = _det3x3(
        ata00, ata01, ata02, ata01, ata11, ata12, ata02, ata12, ata22);

    if (det.abs() < 1e-12) {
      return (
        result: null,
        error: 'System is degenerate (near-zero determinant: $det).',
      );
    }

    // Solve for x-transform parameters [a, b, c]
    final a = _det3x3(
            atbx0, ata01, ata02, atbx1, ata11, ata12, atbx2, ata12, ata22) /
        det;
    final b = _det3x3(
            ata00, atbx0, ata02, ata01, atbx1, ata12, ata02, atbx2, ata22) /
        det;
    final c = _det3x3(
            ata00, ata01, atbx0, ata01, ata11, atbx1, ata02, ata12, atbx2) /
        det;

    // Solve for y-transform parameters [d, e, f]
    final d = _det3x3(
            atby0, ata01, ata02, atby1, ata11, ata12, atby2, ata12, ata22) /
        det;
    final e = _det3x3(
            ata00, atby0, ata02, ata01, atby1, ata12, ata02, atby2, ata22) /
        det;
    final f = _det3x3(
            ata00, ata01, atby0, ata01, ata11, atby1, ata02, ata12, atby2) /
        det;

    // Compute residual errors
    double sumSqError = 0;
    double maxErr = 0;
    for (final s in samples) {
      final tx = a * s.sourceX + b * s.sourceY + c;
      final ty = d * s.sourceX + e * s.sourceY + f;
      final errX = tx - s.destX;
      final errY = ty - s.destY;
      final errSq = errX * errX + errY * errY;
      sumSqError += errSq;
      final err = math.sqrt(errSq);
      if (err > maxErr) maxErr = err;
    }
    final rmsError = math.sqrt(sumSqError / n);

    return (
      result: AffineCalibrationResult(
        parameters: [a, b, c, d, e, f],
        rmsError: rmsError,
        maxError: maxErr,
        sampleCount: n,
      ),
      error: null,
    );
  }

  /// Check if all source points in the samples are collinear.
  bool _areCollinear(List<CalibrationSample> samples) {
    if (samples.length < 3) return true;

    // Check using cross products of vectors from first point.
    final x0 = samples[0].sourceX, y0 = samples[0].sourceY;
    final x1 = samples[1].sourceX, y1 = samples[1].sourceY;

    for (int i = 2; i < samples.length; i++) {
      final xi = samples[i].sourceX, yi = samples[i].sourceY;
      // Cross product of (p1-p0) × (pi-p0)
      final cross = (x1 - x0) * (yi - y0) - (y1 - y0) * (xi - x0);
      if (cross.abs() > 1e-10) return false;
    }
    return true;
  }

  /// 3x3 determinant.
  static double _det3x3(double a00, double a01, double a02, double a10,
      double a11, double a12, double a20, double a21, double a22) {
    return a00 * (a11 * a22 - a12 * a21) -
        a01 * (a10 * a22 - a12 * a20) +
        a02 * (a10 * a21 - a11 * a20);
  }
}
