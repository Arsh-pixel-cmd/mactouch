import 'package:flutter/material.dart';
import '../core/regions/quadrant.dart';

/// Overlay widget that visually renders the 4 quadrants on a display canvas.
///
/// Quadrants:
/// Q1: Top-Left (u < 0.5, v < 0.5)
/// Q2: Top-Right (u >= 0.5, v < 0.5)
/// Q3: Bottom-Left (u < 0.5, v >= 0.5)
/// Q4: Bottom-Right (u >= 0.5, v >= 0.5)
///
/// Deterministic boundary rule: Midpoints (u=0.5, v=0.5) belong to Q2/Q3/Q4.
class QuadrantOverlay extends StatelessWidget {
  /// The currently active quadrant highlighted by the pointer.
  final Quadrant? activeQuadrant;

  /// Whether to show quadrant labels.
  final bool showLabels;

  /// Whether to show axis coordinate labels (u=0.5, v=0.5).
  final bool showMidpointLines;

  const QuadrantOverlay({
    super.key,
    this.activeQuadrant,
    this.showLabels = true,
    this.showMidpointLines = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final halfW = width / 2;
        final halfH = height / 2;

        return Stack(
          children: [
            // Quadrant regions with highlighting
            Positioned(
              left: 0,
              top: 0,
              width: halfW,
              height: halfH,
              child: _QuadrantBox(
                quadrant: Quadrant.topLeft,
                isActive: activeQuadrant == Quadrant.topLeft,
                showLabel: showLabels,
              ),
            ),
            Positioned(
              left: halfW,
              top: 0,
              width: halfW,
              height: halfH,
              child: _QuadrantBox(
                quadrant: Quadrant.topRight,
                isActive: activeQuadrant == Quadrant.topRight,
                showLabel: showLabels,
              ),
            ),
            Positioned(
              left: 0,
              top: halfH,
              width: halfW,
              height: halfH,
              child: _QuadrantBox(
                quadrant: Quadrant.bottomLeft,
                isActive: activeQuadrant == Quadrant.bottomLeft,
                showLabel: showLabels,
              ),
            ),
            Positioned(
              left: halfW,
              top: halfH,
              width: halfW,
              height: halfH,
              child: _QuadrantBox(
                quadrant: Quadrant.bottomRight,
                isActive: activeQuadrant == Quadrant.bottomRight,
                showLabel: showLabels,
              ),
            ),

            // Midpoint dividing lines
            if (showMidpointLines) ...[
              // Vertical center line (u = 0.5)
              Positioned(
                left: halfW - 0.5,
                top: 0,
                bottom: 0,
                width: 1,
                child: Container(color: Colors.blue.withAlpha(120)),
              ),
              // Horizontal center line (v = 0.5)
              Positioned(
                left: 0,
                right: 0,
                top: halfH - 0.5,
                height: 1,
                child: Container(color: Colors.blue.withAlpha(120)),
              ),
              // Center intersection label
              Positioned(
                left: halfW - 22,
                top: halfH - 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(160),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    '(0.5, 0.5)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _QuadrantBox extends StatelessWidget {
  final Quadrant quadrant;
  final bool isActive;
  final bool showLabel;

  const _QuadrantBox({
    required this.quadrant,
    required this.isActive,
    required this.showLabel,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = switch (quadrant) {
      Quadrant.topLeft => Colors.blue,
      Quadrant.topRight => Colors.purple,
      Quadrant.bottomLeft => Colors.teal,
      Quadrant.bottomRight => Colors.amber,
    };

    final bgColor = isActive
        ? baseColor.withAlpha(45)
        : baseColor.withAlpha(10);

    final borderColor = isActive
        ? baseColor.withAlpha(180)
        : Colors.grey.withAlpha(30);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: isActive ? 1.5 : 0.5),
      ),
      padding: const EdgeInsets.all(8),
      child: showLabel
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: baseColor.withAlpha( isActive ? 180 : 80),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'Q${quadrant.number}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      quadrant.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? baseColor : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : null,
    );
  }
}
