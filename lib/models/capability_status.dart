/// Platform capability status model for MacTouch.
///
/// Reports what the current platform actually supports, so the UI can
/// show honest status rather than fabricated data.
library;

/// Overall capability level for a platform feature.
enum CapabilityLevel {
  /// Feature is fully supported and working.
  supported,

  /// Feature is partially supported (some limitations).
  partial,

  /// Feature is not supported on this platform.
  unsupported,

  /// Feature status is unknown (not yet checked).
  unknown,

  /// Feature requires user permission that has not been granted.
  permissionRequired,
}

/// Status of a single platform capability.
class CapabilityStatus {
  /// Name of the capability.
  final String name;

  /// Current support level.
  final CapabilityLevel level;

  /// Human-readable description of what works and what doesn't.
  final String description;

  /// Platform-specific notes (e.g., required permission name).
  final String? platformNote;

  const CapabilityStatus({
    required this.name,
    required this.level,
    required this.description,
    this.platformNote,
  });

  @override
  String toString() => 'CapabilityStatus($name: $level)';
}

/// Aggregated platform capabilities report.
class PlatformCapabilities {
  /// Display enumeration capability.
  final CapabilityStatus displayEnumeration;

  /// In-app pointer event capability (Flutter pointer events).
  final CapabilityStatus inAppPointer;

  /// Global input monitoring capability.
  final CapabilityStatus globalInput;

  /// Touch device discovery capability.
  final CapabilityStatus touchDiscovery;

  /// System tray / menu bar capability.
  final CapabilityStatus systemTray;

  const PlatformCapabilities({
    required this.displayEnumeration,
    required this.inAppPointer,
    required this.globalInput,
    required this.touchDiscovery,
    required this.systemTray,
  });

  /// All capabilities as a list for iteration.
  List<CapabilityStatus> get all => [
        displayEnumeration,
        inAppPointer,
        globalInput,
        touchDiscovery,
        systemTray,
      ];

  /// Default MVP capabilities — honest about what v1 supports.
  factory PlatformCapabilities.mvpDefaults() => const PlatformCapabilities(
        displayEnumeration: CapabilityStatus(
          name: 'Display Enumeration',
          level: CapabilityLevel.partial,
          description: 'Using Flutter window info; native adapter pending.',
          platformNote: 'Full enumeration requires platform-specific plugin.',
        ),
        inAppPointer: CapabilityStatus(
          name: 'In-App Pointer Events',
          level: CapabilityLevel.supported,
          description:
              'Flutter pointer events while the app window is active.',
        ),
        globalInput: CapabilityStatus(
          name: 'Global Input Monitoring',
          level: CapabilityLevel.unsupported,
          description:
              'Not implemented in v1. Requires platform-specific native code '
              'and user permissions.',
          platformNote:
              'macOS: Input Monitoring permission. '
              'Wayland: XDG InputCapture portal.',
        ),
        touchDiscovery: CapabilityStatus(
          name: 'Touch Device Discovery',
          level: CapabilityLevel.unsupported,
          description:
              'Not implemented in v1. Requires hardware with touch support.',
          platformNote: 'A stock MacBook display is NOT a touchscreen.',
        ),
        systemTray: CapabilityStatus(
          name: 'System Tray / Menu Bar',
          level: CapabilityLevel.unsupported,
          description: 'Not implemented in v1 (P2 feature).',
        ),
      );
}
