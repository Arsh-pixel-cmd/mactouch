import 'package:flutter/material.dart';
import '../core/coordinates/coordinate_spaces.dart';
import '../core/regions/quadrant.dart';
import 'quadrant_overlay.dart';

/// An interactive display canvas that visualizes display bounds, quadrants,
/// in-app mouse pointer events, and a movable simulated pointer.
///
/// Features:
/// - In-app pointer capture using normal Flutter `Listener` / `MouseRegion`
///   (ONLY while the app window is active).
/// - Simulated pointer draggable or positionable by coordinates.
/// - Clear visual distinction between simulated pointer and active mouse.
/// - Honest non-touch feedback.
class DisplayCanvas extends StatefulWidget {
  final DisplayBounds displayBounds;
  final NormalizedPoint simulatedPointer;
  final ValueChanged<NormalizedPoint>? onSimulatedPointerChanged;
  final ValueChanged<NormalizedPoint>? onInAppPointerHover;
  final ValueChanged<NormalizedPoint>? onInAppPointerClick;
  final List<({double u, double v, String label})> calibrationTargets;

  const DisplayCanvas({
    super.key,
    required this.displayBounds,
    required this.simulatedPointer,
    this.onSimulatedPointerChanged,
    this.onInAppPointerHover,
    this.onInAppPointerClick,
    this.calibrationTargets = const [],
  });

  @override
  State<DisplayCanvas> createState() => _DisplayCanvasState();
}

class _DisplayCanvasState extends State<DisplayCanvas> {
  NormalizedPoint? _hoverPoint;
  bool _isDraggingSimulator = false;

  @override
  Widget build(BuildContext context) {
    final activeQuadrant = getQuadrant(
      _isDraggingSimulator ? widget.simulatedPointer : (_hoverPoint ?? widget.simulatedPointer),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Maintain the aspect ratio of the display within constraints
        final aspectRatio = widget.displayBounds.isValid
            ? (widget.displayBounds.width / widget.displayBounds.height)
            : (16 / 9);

        double canvasWidth = constraints.maxWidth;
        double canvasHeight = canvasWidth / aspectRatio;

        if (canvasHeight > constraints.maxHeight) {
          canvasHeight = constraints.maxHeight;
          canvasWidth = canvasHeight * aspectRatio;
        }

        return Center(
          child: Container(
            width: canvasWidth,
            height: canvasHeight,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(240),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blueGrey.shade700, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(60),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Listener(
                onPointerHover: (event) {
                  final u = (event.localPosition.dx / canvasWidth).clamp(0.0, 1.0);
                  final v = (event.localPosition.dy / canvasHeight).clamp(0.0, 1.0);
                  final norm = NormalizedPoint(u, v);
                  setState(() => _hoverPoint = norm);
                  widget.onInAppPointerHover?.call(norm);
                },
                onPointerDown: (event) {
                  final u = (event.localPosition.dx / canvasWidth).clamp(0.0, 1.0);
                  final v = (event.localPosition.dy / canvasHeight).clamp(0.0, 1.0);
                  final norm = NormalizedPoint(u, v);
                  widget.onInAppPointerClick?.call(norm);
                },
                child: MouseRegion(
                  onExit: (_) {
                    setState(() => _hoverPoint = null);
                  },
                  child: Stack(
                    children: [
                      // Quadrant Overlay
                      QuadrantOverlay(
                        activeQuadrant: activeQuadrant,
                        showLabels: true,
                        showMidpointLines: true,
                      ),

                      // Calibration Targets (Visual Prompts Only - Not Contact Sensors)
                      for (final target in widget.calibrationTargets)
                        Positioned(
                          left: target.u * canvasWidth - 14,
                          top: target.v * canvasHeight - 14,
                          child: _CalibrationTargetPrompt(label: target.label),
                        ),

                      // Real In-App Pointer (if hovering inside app window)
                      if (_hoverPoint != null)
                        Positioned(
                          left: _hoverPoint!.u * canvasWidth - 5,
                          top: _hoverPoint!.v * canvasHeight - 5,
                          child: IgnorePointer(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),

                      // Simulated Pointer (Draggable Reticle)
                      Positioned(
                        left: widget.simulatedPointer.u * canvasWidth - 18,
                        top: widget.simulatedPointer.v * canvasHeight - 18,
                        child: GestureDetector(
                          onPanStart: (_) {
                            setState(() => _isDraggingSimulator = true);
                          },
                          onPanUpdate: (details) {
                            final newDx = widget.simulatedPointer.u * canvasWidth + details.delta.dx;
                            final newDy = widget.simulatedPointer.v * canvasHeight + details.delta.dy;
                            final u = (newDx / canvasWidth).clamp(0.0, 1.0);
                            final v = (newDy / canvasHeight).clamp(0.0, 1.0);
                            widget.onSimulatedPointerChanged?.call(NormalizedPoint(u, v));
                          },
                          onPanEnd: (_) {
                            setState(() => _isDraggingSimulator = false);
                          },
                          child: _SimulatedPointerReticle(
                            isDragging: _isDraggingSimulator,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Visual reticle representing the simulated pointer.
class _SimulatedPointerReticle extends StatelessWidget {
  final bool isDragging;

  const _SimulatedPointerReticle({required this.isDragging});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Simulated Pointer (Drag to move or use coordinate slider)',
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDragging ? Colors.amberAccent : Colors.purpleAccent,
              width: 2,
            ),
            color: (isDragging ? Colors.amber : Colors.purple).withAlpha(60),
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDragging ? Colors.amberAccent : Colors.purpleAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Visual prompt for calibration target (Prompt only — NOT a contact sensor).
class _CalibrationTargetPrompt extends StatelessWidget {
  final String label;

  const _CalibrationTargetPrompt({required this.label});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Visual prompt ($label): Prompts user for sample coordinate. Does not sense contact.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.redAccent, width: 2),
              color: Colors.red.withAlpha(40),
            ),
            child: const Center(
              child: Icon(Icons.add, size: 16, color: Colors.redAccent),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 8, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
