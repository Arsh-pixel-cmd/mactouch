import 'package:flutter/material.dart';
import '../models/capability_status.dart';

/// Renders a color-coded status badge for a [CapabilityLevel].
class CapabilityBadge extends StatelessWidget {
  final CapabilityLevel level;
  final bool showLabel;

  const CapabilityBadge({
    super.key,
    required this.level,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (level) {
      CapabilityLevel.supported => (
          Colors.green.shade700,
          'Supported',
          Icons.check_circle_outline,
        ),
      CapabilityLevel.partial => (
          Colors.orange.shade800,
          'Partial / Estimated',
          Icons.warning_amber_rounded,
        ),
      CapabilityLevel.unsupported => (
          Colors.grey.shade600,
          'Unsupported in v1',
          Icons.block_outlined,
        ),
      CapabilityLevel.permissionRequired => (
          Colors.deepOrange.shade700,
          'Permission Required',
          Icons.lock_outline,
        ),
      CapabilityLevel.unknown => (
          Colors.blueGrey.shade400,
          'Unknown',
          Icons.help_outline,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(120), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A card displaying capability details with honest explanations.
class CapabilityCard extends StatelessWidget {
  final CapabilityStatus capability;

  const CapabilityCard({super.key, required this.capability});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.withAlpha(40)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    capability.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                CapabilityBadge(level: capability.level),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              capability.description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            ),
            if (capability.platformNote != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withAlpha(15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 13, color: Colors.blueGrey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        capability.platformNote!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
