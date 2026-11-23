import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/coordinates/coordinate_spaces.dart';
import '../../core/regions/quadrant.dart';
import '../../models/display_info.dart';
import '../../services/display_service.dart';
import '../../services/touch_server_service.dart';
import '../../services/system_cursor_service.dart';
import '../../widgets/capability_badge.dart';
import '../../widgets/coordinate_readout.dart';
import '../../widgets/display_canvas.dart';

/// Main dashboard screen for display inspection and coordinate visualization.
class DashboardScreen extends StatefulWidget {
  final DisplayService displayService;
  final TouchServerService? touchServer;
  final SystemCursorService? cursorService;

  const DashboardScreen({
    super.key,
    required this.displayService,
    this.touchServer,
    this.cursorService,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  NormalizedPoint _simulatedPointer = const NormalizedPoint(0.5, 0.5);
  NormalizedPoint? _inAppHoverPoint;
  bool _useSimulatedAsActive = true;
  StreamSubscription<PhoneTouchEvent>? _touchSubscription;
  StreamSubscription<int>? _clientCountSubscription;
  int _connectedPhones = 0;
  bool _controlSystemCursor = true;

  @override
  void initState() {
    super.initState();
    _refreshDisplays();
    _initTouchServerListeners();
  }

  void _initTouchServerListeners() {
    _touchSubscription = widget.touchServer?.onTouchEvent.listen((event) {
      if (!mounted) return;

      final selectedDisplay = widget.displayService.selectedDisplay;
      final bounds = selectedDisplay?.bounds ??
          const DisplayBounds(left: 0, top: 0, width: 1440, height: 900);
      final mapper = CoordinateMapper(bounds);

      if (event.type == 'move' && event.dx != null && event.dy != null) {
        if (_controlSystemCursor) {
          widget.cursorService?.moveRelative(event.dx!, event.dy!);
        }
      } else if (event.type == 'abs' && event.u != null && event.v != null) {
        final norm = NormalizedPoint(event.u!, event.v!);
        setState(() {
          _simulatedPointer = norm;
          _useSimulatedAsActive = true;
        });
        if (_controlSystemCursor && bounds.isValid) {
          final pt = mapper.fromNormalized(norm);
          widget.cursorService?.moveTo(pt.x, pt.y);
        }
      } else if (event.type == 'click') {
        if (_controlSystemCursor) {
          widget.cursorService?.click();
        }
      } else if (event.type == 'rclick') {
        if (_controlSystemCursor) {
          widget.cursorService?.rightClick();
        }
      } else if (event.type == 'down') {
        if (_controlSystemCursor) {
          widget.cursorService?.mouseDown();
        }
      } else if (event.type == 'up') {
        if (_controlSystemCursor) {
          widget.cursorService?.mouseUp();
        }
      } else if (event.type == 'scroll' && event.scrollDy != null) {
        if (_controlSystemCursor) {
          widget.cursorService?.scroll(event.scrollDy!);
        }
      }
    });

    _clientCountSubscription = widget.touchServer?.onClientCountChanged.listen((count) {
      if (mounted) setState(() => _connectedPhones = count);
    });

    _connectedPhones = widget.touchServer?.connectedClients ?? 0;
    _controlSystemCursor = widget.cursorService?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _touchSubscription?.cancel();
    _clientCountSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshDisplays() async {
    await widget.displayService.enumerate();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final displays = widget.displayService.displays;
    final selectedDisplay = widget.displayService.selectedDisplay;
    final bounds = selectedDisplay?.bounds ??
        const DisplayBounds(left: 0, top: 0, width: 1440, height: 900);
    final mapper = CoordinateMapper(bounds);

    // Active point based on selection
    final activeNormPoint = _useSimulatedAsActive
        ? _simulatedPointer
        : (_inAppHoverPoint ?? _simulatedPointer);

    final desktopPoint = bounds.isValid
        ? mapper.fromNormalized(activeNormPoint)
        : null;

    final activeQuadrant = getQuadrant(activeNormPoint);

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Main Canvas Area
          Expanded(
            flex: 6,
            child: Container(
              color: const Color(0xFF16181D),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Toolbar: Display Selector & Quick Refresh
                  Row(
                    children: [
                      const Icon(Icons.monitor, size: 18, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      const Text(
                        'Display Canvas',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (displays.isNotEmpty)
                        SizedBox(
                          width: 260,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF222630),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                dropdownColor: const Color(0xFF222630),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                value: selectedDisplay?.id ?? (displays.isNotEmpty ? displays.first.id : null),
                                items: displays.map((d) {
                                  return DropdownMenuItem<String>(
                                    value: d.id,
                                    child: Text(
                                      '${d.name} (${d.bounds.width.toInt()}x${d.bounds.height.toInt()})'
                                      '${d.isPrimary ? " [Primary]" : ""}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (id) {
                                  if (id != null) {
                                    setState(() {
                                      widget.displayService.selectDisplayById(id);
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18, color: Colors.white70),
                        tooltip: 'Re-enumerate Displays',
                        onPressed: _refreshDisplays,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Interactive Display Canvas with Quadrant Overlay & Pointer Simulator
                  Expanded(
                    child: DisplayCanvas(
                      displayBounds: bounds,
                      simulatedPointer: _simulatedPointer,
                      onSimulatedPointerChanged: (norm) {
                        setState(() {
                          _simulatedPointer = norm;
                          _useSimulatedAsActive = true;
                        });
                      },
                      onInAppPointerHover: (norm) {
                        setState(() {
                          _inAppHoverPoint = norm;
                          _useSimulatedAsActive = false;
                        });
                      },
                      onInAppPointerClick: (norm) {
                        setState(() {
                          _simulatedPointer = norm;
                          _useSimulatedAsActive = true;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bottom Notice Banner: Product Truth & Honesty
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: Colors.lightBlueAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Notice: Conventional MacBook screens lack touch sensors. '
                            'Canvas demonstrates deterministic quadrant math & simulated pointer positioning. '
                            'No OS cursor synthesis or global hooks are active.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right Sidebar: Coordinates, Bounds, Simulator Controls & Capabilities
          Expanded(
            flex: 4,
            child: Container(
              color: const Color(0xFF1E222B),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Smartphone Touch Digitizer Connection Card
                    if (widget.touchServer != null) ...[
                      Card(
                        elevation: 0,
                        color: const Color(0xFF232A36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: _connectedPhones > 0
                                ? Colors.greenAccent.withAlpha(180)
                                : Colors.blueAccent.withAlpha(120),
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone_iphone,
                                    size: 18,
                                    color: _connectedPhones > 0
                                        ? Colors.greenAccent
                                        : Colors.cyanAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Phone Touch Controller',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _connectedPhones > 0
                                          ? Colors.green.withAlpha(40)
                                          : Colors.orange.withAlpha(30),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: _connectedPhones > 0
                                            ? Colors.greenAccent
                                            : Colors.orangeAccent,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _connectedPhones > 0
                                                ? Colors.greenAccent
                                                : Colors.orangeAccent,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _connectedPhones > 0
                                              ? '$_connectedPhones Connected'
                                              : 'Waiting for Phone',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: _connectedPhones > 0
                                                ? Colors.greenAccent
                                                : Colors.orangeAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Open this URL in Safari (iPhone) or Chrome (Android) on the same Wi-Fi:',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SelectableText(
                                        widget.touchServer!.connectionUrl,
                                        style: const TextStyle(
                                          color: Colors.cyanAccent,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 14, color: Colors.white70),
                                      tooltip: 'Copy URL',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: widget.touchServer!.connectionUrl));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Phone URL copied to clipboard!'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Control macOS Cursor',
                                      style: TextStyle(fontSize: 11, color: Colors.white70),
                                    ),
                                  ),
                                  Switch(
                                    value: _controlSystemCursor,
                                    activeColor: Colors.greenAccent,
                                    onChanged: (val) {
                                      setState(() {
                                        _controlSystemCursor = val;
                                        widget.cursorService?.setEnabled(val);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Active Coordinate Readout Card
                    CoordinateReadout(
                      desktopPoint: desktopPoint,
                      normalizedPoint: activeNormPoint,
                      bounds: bounds,
                      quadrant: activeQuadrant,
                      sourceLabel: _useSimulatedAsActive
                          ? 'Simulated Pointer'
                          : 'In-App Mouse Pointer',
                      isSimulated: _useSimulatedAsActive,
                    ),
                    const SizedBox(height: 14),

                    // Pointer Simulator Position Sliders
                    Card(
                      elevation: 0,
                      color: const Color(0xFF282D38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Colors.white12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.tune, size: 16, color: Colors.purpleAccent),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Simulator Controls',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _simulatedPointer = const NormalizedPoint(0.5, 0.5);
                                      _useSimulatedAsActive = true;
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Center', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Normalized X (u): ${_simulatedPointer.u.toStringAsFixed(3)}',
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                            Slider(
                              value: _simulatedPointer.u,
                              activeColor: Colors.purpleAccent,
                              onChanged: (val) {
                                setState(() {
                                  _simulatedPointer = NormalizedPoint(val, _simulatedPointer.v);
                                  _useSimulatedAsActive = true;
                                });
                              },
                            ),
                            Text(
                              'Normalized Y (v): ${_simulatedPointer.v.toStringAsFixed(3)}',
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                            Slider(
                              value: _simulatedPointer.v,
                              activeColor: Colors.purpleAccent,
                              onChanged: (val) {
                                setState(() {
                                  _simulatedPointer = NormalizedPoint(_simulatedPointer.u, val);
                                  _useSimulatedAsActive = true;
                                });
                              },
                            ),
                            // Quadrant quick jump presets
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _QuickPresetButton(
                                  label: 'Q1 (0.25, 0.25)',
                                  onTap: () => setState(() {
                                    _simulatedPointer = const NormalizedPoint(0.25, 0.25);
                                    _useSimulatedAsActive = true;
                                  }),
                                ),
                                _QuickPresetButton(
                                  label: 'Q2 (0.75, 0.25)',
                                  onTap: () => setState(() {
                                    _simulatedPointer = const NormalizedPoint(0.75, 0.25);
                                    _useSimulatedAsActive = true;
                                  }),
                                ),
                                _QuickPresetButton(
                                  label: 'Q3 (0.25, 0.75)',
                                  onTap: () => setState(() {
                                    _simulatedPointer = const NormalizedPoint(0.25, 0.75);
                                    _useSimulatedAsActive = true;
                                  }),
                                ),
                                _QuickPresetButton(
                                  label: 'Q4 (0.75, 0.75)',
                                  onTap: () => setState(() {
                                    _simulatedPointer = const NormalizedPoint(0.75, 0.75);
                                    _useSimulatedAsActive = true;
                                  }),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Display Bounds & Topology Card
                    Card(
                      elevation: 0,
                      color: const Color(0xFF282D38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Colors.white12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.desktop_windows, size: 16, color: Colors.tealAccent),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Display Topology',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (selectedDisplay != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: selectedDisplay.boundsStatus == DisplayValueStatus.reported
                                          ? Colors.green.withAlpha(30)
                                          : Colors.orange.withAlpha(30),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      selectedDisplay.boundsStatus == DisplayValueStatus.reported
                                          ? 'Reported'
                                          : 'Estimated',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: selectedDisplay.boundsStatus == DisplayValueStatus.reported
                                            ? Colors.greenAccent
                                            : Colors.orangeAccent,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const Divider(color: Colors.white10, height: 16),
                            _TopologyRow('Origin (Left, Top)', '(${bounds.left.toInt()}, ${bounds.top.toInt()})'),
                            _TopologyRow('Dimensions (W x H)', '${bounds.width.toInt()} x ${bounds.height.toInt()} pt'),
                            _TopologyRow('Scale Factor (DPR)', '${selectedDisplay?.scaleFactor ?? 1.0}x'),
                            _TopologyRow('Physical Resolution', '${(bounds.width * (selectedDisplay?.scaleFactor ?? 1.0)).toInt()} x ${(bounds.height * (selectedDisplay?.scaleFactor ?? 1.0)).toInt()} px'),
                            _TopologyRow('Primary Display', selectedDisplay?.isPrimary == true ? 'Yes' : 'No'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Platform Capability Status
                    Card(
                      elevation: 0,
                      color: const Color(0xFF282D38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Colors.white12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified_user_outlined, size: 16, color: Colors.blueAccent),
                                const SizedBox(width: 8),
                                const Text(
                                  'Platform Capability',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text('Display Adapter', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ),
                                CapabilityBadge(level: widget.displayService.capability.level),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.displayService.capability.description,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopologyRow extends StatelessWidget {
  final String label;
  final String value;

  const _TopologyRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPresetButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickPresetButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 9, color: Colors.white70),
        ),
      ),
    );
  }
}
