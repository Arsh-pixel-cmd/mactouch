import 'package:flutter/material.dart';
import '../../models/capability_status.dart';
import '../../platforms/display_adapter.dart';
import '../../services/display_service.dart';
import '../../services/profile_store.dart';
import '../../widgets/capability_badge.dart';

/// Settings screen for inspecting platform capabilities, toggling display adapters,
/// and viewing profile persistence status.
class SettingsScreen extends StatefulWidget {
  final DisplayService displayService;
  final ProfileStore profileStore;

  const SettingsScreen({
    super.key,
    required this.displayService,
    required this.profileStore,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _useSimulatedDisplay = false;

  @override
  void initState() {
    super.initState();
    _useSimulatedDisplay = widget.displayService.adapter is SimulatedDisplayAdapter;
  }

  void _toggleDisplayAdapter(bool simulated) {
    setState(() {
      _useSimulatedDisplay = simulated;
      if (simulated) {
        widget.displayService.setAdapter(const SimulatedDisplayAdapter());
      } else {
        widget.displayService.setAdapter(const FlutterWindowDisplayAdapter());
      }
    });
    widget.displayService.enumerate();
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = PlatformCapabilities.mvpDefaults();

    return Scaffold(
      backgroundColor: const Color(0xFF16181D),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings & Platform Capability Matrix',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Honest capability reporting and system boundary configuration for MacTouch v1.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Display Adapter Mode Switcher
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
                        const Icon(Icons.settings_input_component, color: Colors.blueAccent, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Display Discovery Source',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Choose whether to inspect the active Flutter window view or use the simulated multi-display topology (including negative origins) for testing.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Use Simulated Multi-Display Adapter', style: TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: Text(
                        _useSimulatedDisplay
                            ? 'Simulated: Primary 1440x900 + Secondary 1920x1080 at negative origin (-1920, 0).'
                            : 'Live Window: Queries active Flutter PlatformDispatcher window dimensions.',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      value: _useSimulatedDisplay,
                      activeTrackColor: Colors.purpleAccent,
                      onChanged: _toggleDisplayAdapter,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Platform Capabilities Breakdown
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
                        const Icon(Icons.shield_outlined, color: Colors.tealAccent, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Platform Capabilities & Permissions Truth Table',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    for (final cap in capabilities.all) ...[
                      CapabilityCard(capability: cap),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Profile Storage Management
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
                        const Icon(Icons.storage_outlined, color: Colors.amberAccent, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Profile Persistence (Versioned Local JSON)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Store File Path: ${widget.profileStore.filePath}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Loaded Profiles: ${widget.profileStore.profiles.length}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Reload from Disk'),
                          onPressed: () async {
                            await widget.profileStore.load();
                            setState(() {});
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: Colors.redAccent),
                          label: const Text('Reset All Profiles', style: TextStyle(color: Colors.redAccent)),
                          onPressed: () async {
                            await widget.profileStore.reset();
                            setState(() {});
                          },
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
    );
  }
}
