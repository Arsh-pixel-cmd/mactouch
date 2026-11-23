import 'package:flutter/material.dart';
import '../../core/calibration/affine_calibration.dart';
import '../../models/calibration_profile.dart';
import '../../services/display_service.dart';
import '../../services/profile_store.dart';

/// Screen for calibration profile management, sample entry, and affine transform calculation.
///
/// Non-goals & honest limitations:
/// - MacBook displays are not touchscreens.
/// - Targets displayed on screen do NOT detect contact.
/// - Samples are manually entered or simulated to calculate coordinate transforms.
class CalibrationScreen extends StatefulWidget {
  final DisplayService displayService;
  final ProfileStore profileStore;

  const CalibrationScreen({
    super.key,
    required this.displayService,
    required this.profileStore,
  });

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  final List<CalibrationSample> _samples = [];
  final AffineCalibrator _calibrator = AffineCalibrator();
  AffineCalibrationResult? _calibrationResult;
  String? _calibrationError;

  // Manual entry controllers
  final _srcXController = TextEditingController(text: '100');
  final _srcYController = TextEditingController(text: '100');
  final _destXController = TextEditingController(text: '102');
  final _destYController = TextEditingController(text: '98');

  // Test transform controllers
  final _testSrcXController = TextEditingController(text: '200');
  final _testSrcYController = TextEditingController(text: '300');
  ({double x, double y})? _testTransformedPoint;

  String? _selectedProfileId;
  final String _profileName = 'Default Calibration';

  @override
  void initState() {
    super.initState();
    _loadInitialSamples();
  }

  void _loadInitialSamples() {
    // Populate with 4 standard simulated calibration samples
    _samples.clear();
    _samples.addAll(const [
      CalibrationSample(sourceX: 100, sourceY: 100, destX: 102, destY: 98),
      CalibrationSample(sourceX: 900, sourceY: 100, destX: 898, destY: 101),
      CalibrationSample(sourceX: 900, sourceY: 600, destX: 897, destY: 603),
      CalibrationSample(sourceX: 100, sourceY: 600, destX: 101, destY: 598),
    ]);
    _recomputeCalibration();
  }

  void _recomputeCalibration() {
    final res = _calibrator.calibrate(_samples);
    setState(() {
      _calibrationResult = res.result;
      _calibrationError = res.error;
      _runTestTransform();
    });
  }

  void _runTestTransform() {
    if (_calibrationResult == null) {
      _testTransformedPoint = null;
      return;
    }
    final tx = double.tryParse(_testSrcXController.text) ?? 0.0;
    final ty = double.tryParse(_testSrcYController.text) ?? 0.0;
    _testTransformedPoint = _calibrationResult!.transform(tx, ty);
  }

  void _addManualSample() {
    final sx = double.tryParse(_srcXController.text);
    final sy = double.tryParse(_srcYController.text);
    final dx = double.tryParse(_destXController.text);
    final dy = double.tryParse(_destYController.text);

    if (sx == null || sy == null || dx == null || dy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid numeric coordinates.')),
      );
      return;
    }

    setState(() {
      _samples.add(CalibrationSample(
        sourceX: sx,
        sourceY: sy,
        destX: dx,
        destY: dy,
      ));
      _recomputeCalibration();
    });
  }

  void _loadPreset(String preset) {
    setState(() {
      _samples.clear();
      if (preset == '4-corners') {
        _samples.addAll(const [
          CalibrationSample(sourceX: 50, sourceY: 50, destX: 52, destY: 49),
          CalibrationSample(sourceX: 950, sourceY: 50, destX: 948, destY: 51),
          CalibrationSample(sourceX: 950, sourceY: 650, destX: 949, destY: 652),
          CalibrationSample(sourceX: 50, sourceY: 650, destX: 51, destY: 648),
        ]);
      } else if (preset == '5-cross') {
        _samples.addAll(const [
          CalibrationSample(sourceX: 500, sourceY: 350, destX: 500, destY: 350),
          CalibrationSample(sourceX: 500, sourceY: 80, destX: 501, destY: 79),
          CalibrationSample(sourceX: 920, sourceY: 350, destX: 918, destY: 351),
          CalibrationSample(sourceX: 500, sourceY: 620, destX: 499, destY: 622),
          CalibrationSample(sourceX: 80, sourceY: 350, destX: 81, destY: 349),
        ]);
      } else if (preset == 'collinear-test') {
        // Degenerate test preset
        _samples.addAll(const [
          CalibrationSample(sourceX: 100, sourceY: 100, destX: 100, destY: 100),
          CalibrationSample(sourceX: 200, sourceY: 200, destX: 200, destY: 200),
          CalibrationSample(sourceX: 300, sourceY: 300, destX: 300, destY: 300),
        ]);
      }
      _recomputeCalibration();
    });
  }

  Future<void> _saveProfile() async {
    final now = DateTime.now().toIso8601String();
    final profile = CalibrationProfile(
      id: _selectedProfileId ?? 'profile-${DateTime.now().millisecondsSinceEpoch}',
      name: _profileName,
      displayId: widget.displayService.selectedDisplay?.id,
      samples: List.of(_samples),
      calibrationResult: _calibrationResult,
      createdAt: now,
      modifiedAt: now,
    );

    if (_selectedProfileId != null) {
      widget.profileStore.updateProfile(profile);
    } else {
      widget.profileStore.addProfile(profile);
      _selectedProfileId = profile.id;
    }
    await widget.profileStore.save();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile "$_profileName" saved successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF16181D),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Prominent Non-Contact Disclaimer Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade900.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade700, width: 1.2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hardware Truth & Scope Disclaimer',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'A conventional MacBook screen is NOT a touchscreen. Calibration targets cannot sense contact. '
                          'In this MVP, samples are manually entered or simulated correspondences between coordinate systems. '
                          'Calibration computes an affine transform (x\' = ax + by + c, y\' = dx + ey + f) '
                          'requiring at least 3 non-collinear points.',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade100),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Top Row: Presets and Sample Points Table
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Sample Correspondences Table
                Expanded(
                  flex: 6,
                  child: Card(
                    color: const Color(0xFF1E222B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.white12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.table_chart_outlined, size: 18, color: Colors.blueAccent),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Sample Correspondences',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_samples.length} Samples',
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Preset buttons
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ActionChip(
                                label: const Text('4 Corners Preset', style: TextStyle(fontSize: 11)),
                                onPressed: () => _loadPreset('4-corners'),
                              ),
                              ActionChip(
                                label: const Text('5-Point Cross Preset', style: TextStyle(fontSize: 11)),
                                onPressed: () => _loadPreset('5-cross'),
                              ),
                              ActionChip(
                                label: const Text('Collinear Test (Degenerate)', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                                onPressed: () => _loadPreset('collinear-test'),
                              ),
                              ActionChip(
                                label: const Text('Clear All', style: TextStyle(fontSize: 11)),
                                onPressed: () {
                                  setState(() {
                                    _samples.clear();
                                    _recomputeCalibration();
                                  });
                                },
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 24),

                          // Table of points
                          if (_samples.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'No sample points entered.\nAdd manual samples or choose a preset above.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white38),
                                ),
                              ),
                            )
                          else
                            Table(
                              columnWidths: const {
                                0: FlexColumnWidth(1),
                                1: FlexColumnWidth(3),
                                2: FlexColumnWidth(3),
                                3: FlexColumnWidth(1),
                              },
                              children: [
                                const TableRow(
                                  decoration: BoxDecoration(color: Colors.black26),
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 11)),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Text('Source (Simulated / Input)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 11)),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Text('Destination (Target Display)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 11)),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 11)),
                                    ),
                                  ],
                                ),
                                for (int i = 0; i < _samples.length; i++)
                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: i % 2 == 0 ? Colors.white.withAlpha(5) : Colors.transparent,
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Text('${i + 1}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Text(
                                          '(${_samples[i].sourceX.toStringAsFixed(1)}, ${_samples[i].sourceY.toStringAsFixed(1)})',
                                          style: const TextStyle(fontFamily: 'monospace', color: Colors.cyanAccent, fontSize: 12),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Text(
                                          '(${_samples[i].destX.toStringAsFixed(1)}, ${_samples[i].destY.toStringAsFixed(1)})',
                                          style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 12),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                          onPressed: () {
                                            setState(() {
                                              _samples.removeAt(i);
                                              _recomputeCalibration();
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          const Divider(color: Colors.white12, height: 24),

                          // Add Manual Sample Input Fields
                          const Text(
                            'Add Manual Sample',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _CoordInput(controller: _srcXController, label: 'Src X'),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _CoordInput(controller: _srcYController, label: 'Src Y'),
                              ),
                              const SizedBox(width: 14),
                              const Icon(Icons.arrow_forward, size: 16, color: Colors.white38),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _CoordInput(controller: _destXController, label: 'Dest X'),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _CoordInput(controller: _destYController, label: 'Dest Y'),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: _addManualSample,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                child: const Text('Add Point'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Right Column: Transform Result & Error Analysis
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      // Computed Transform Card
                      Card(
                        color: const Color(0xFF1E222B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.white12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calculate_outlined, size: 18, color: Colors.purpleAccent),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Affine Transform Solution',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_calibrationResult != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withAlpha(30),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.greenAccent),
                                      ),
                                      child: const Text(
                                        'SOLVED',
                                        style: TextStyle(
                                          color: Colors.greenAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_calibrationError != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withAlpha(30),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.redAccent.withAlpha(100)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _calibrationError!,
                                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (_calibrationResult != null) ...[
                                const Text(
                                  'Affine Matrix Parameters:',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'x\' = ${_calibrationResult!.parameters[0].toStringAsFixed(4)}·x + ${_calibrationResult!.parameters[1].toStringAsFixed(4)}·y + ${_calibrationResult!.parameters[2].toStringAsFixed(2)}',
                                        style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontSize: 12),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'y\' = ${_calibrationResult!.parameters[3].toStringAsFixed(4)}·x + ${_calibrationResult!.parameters[4].toStringAsFixed(4)}·y + ${_calibrationResult!.parameters[5].toStringAsFixed(2)}',
                                        style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MetricBadge(
                                        label: 'RMS Error',
                                        value: '${_calibrationResult!.rmsError.toStringAsFixed(4)} px',
                                        isGood: _calibrationResult!.rmsError < 3.0,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _MetricBadge(
                                        label: 'Max Error',
                                        value: '${_calibrationResult!.maxError.toStringAsFixed(4)} px',
                                        isGood: _calibrationResult!.maxError < 5.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const Divider(color: Colors.white12, height: 24),

                              // Interactive Test Transform Tool
                              const Text(
                                'Test Transform on Arbitrary Point',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _CoordInput(
                                      controller: _testSrcXController,
                                      label: 'Test X',
                                      onChanged: (_) => setState(_runTestTransform),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _CoordInput(
                                      controller: _testSrcYController,
                                      label: 'Test Y',
                                      onChanged: (_) => setState(_runTestTransform),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.arrow_forward, size: 16, color: Colors.white38),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.white12),
                                      ),
                                      child: Text(
                                        _testTransformedPoint != null
                                            ? '(${_testTransformedPoint!.x.toStringAsFixed(1)}, ${_testTransformedPoint!.y.toStringAsFixed(1)})'
                                            : 'No valid transform',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _testTransformedPoint != null ? Colors.greenAccent : Colors.white38,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white12, height: 24),

                              // Save & Profile Controls
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.save_outlined, size: 16),
                                      label: const Text('Save Profile to JSON'),
                                      onPressed: _calibrationResult != null ? _saveProfile : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.restart_alt, size: 16),
                                    label: const Text('Reset'),
                                    onPressed: _loadInitialSamples,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      side: const BorderSide(color: Colors.white24),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

class _CoordInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;

  const _CoordInput({
    required this.controller,
    required this.label,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
        isDense: true,
        filled: true,
        fillColor: Colors.black26,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.white12)),
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;
  final String value;
  final bool isGood;

  const _MetricBadge({
    required this.label,
    required this.value,
    required this.isGood,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isGood ? Colors.green.withAlpha(20) : Colors.orange.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isGood ? Colors.greenAccent.withAlpha(80) : Colors.orangeAccent.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isGood ? Colors.greenAccent : Colors.orangeAccent,
            ),
          ),
        ],
      ),
    );
  }
}
