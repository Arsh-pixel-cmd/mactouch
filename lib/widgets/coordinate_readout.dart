import 'package:flutter/material.dart';
import '../core/coordinates/coordinate_spaces.dart';
import '../core/regions/quadrant.dart';

/// Formatted readout card for live coordinate values across multiple spaces.
class CoordinateReadout extends StatelessWidget {
  /// The point in desktop-global coordinates.
  final CoordinatePoint? desktopPoint;

  /// The point normalized [0, 1] relative to active display bounds.
  final NormalizedPoint? normalizedPoint;

  /// Display bounds currently used for mapping.
  final DisplayBounds? bounds;

  /// The active quadrant (Q1-Q4) or null if out of bounds.
  final Quadrant? quadrant;

  /// Label indicating the source of coordinates (e.g. "Simulated Pointer" or "In-App Mouse").
  final String sourceLabel;

  /// Whether the pointer is simulated.
  final bool isSimulated;

  const CoordinateReadout({
    super.key,
    required this.desktopPoint,
    required this.normalizedPoint,
    required this.bounds,
    required this.quadrant,
    this.sourceLabel = 'Active Pointer',
    this.isSimulated = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSimulated ? Icons.gps_fixed : Icons.mouse,
                  size: 16,
                  color: isSimulated ? Colors.purple : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sourceLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSimulated
                        ? Colors.purple.withAlpha(25)
                        : Colors.blue.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSimulated ? Colors.purple : Colors.blue,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    isSimulated ? 'SIMULATED DATA' : 'IN-APP EVENT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSimulated ? Colors.purple : Colors.blue,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MetricCell(
                    title: 'Desktop-Global',
                    value: desktopPoint != null
                        ? '(${desktopPoint!.x.toStringAsFixed(1)}, ${desktopPoint!.y.toStringAsFixed(1)})'
                        : '—',
                    subtitle: 'Logical Points',
                  ),
                ),
                Expanded(
                  child: _MetricCell(
                    title: 'Normalized [u, v]',
                    value: normalizedPoint != null
                        ? '(${normalizedPoint!.u.toStringAsFixed(3)}, ${normalizedPoint!.v.toStringAsFixed(3)})'
                        : '—',
                    subtitle: normalizedPoint?.isInBounds == true
                        ? 'In-Bounds'
                        : (normalizedPoint != null ? 'Out-of-Bounds' : '—'),
                    valueColor: normalizedPoint?.isInBounds == false
                        ? Colors.red
                        : null,
                  ),
                ),
                Expanded(
                  child: _MetricCell(
                    title: 'Quadrant',
                    value: quadrant != null ? 'Q${quadrant!.number}' : 'None',
                    subtitle: quadrant != null ? quadrant!.label : 'Out of Display',
                    valueColor: quadrant != null ? Colors.teal : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color? valueColor;

  const _MetricCell({
    required this.title,
    required this.value,
    required this.subtitle,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}
