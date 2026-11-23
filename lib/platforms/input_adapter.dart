/// Platform adapter interface for input sources.
///
/// In MVP, only in-app Flutter pointer events are supported.
/// Global input monitoring and touch device discovery are explicitly
/// out of scope (P2/P3) and require separate platform-specific implementation.
library;

import '../models/capability_status.dart';

/// Describes a detected input device.
class InputDeviceInfo {
  /// Device identifier.
  final String id;

  /// Human-readable name.
  final String name;

  /// Type of input device.
  final InputDeviceType type;

  /// Whether this device is currently available.
  final bool isAvailable;

  const InputDeviceInfo({
    required this.id,
    required this.name,
    required this.type,
    this.isAvailable = true,
  });
}

/// Types of input devices.
enum InputDeviceType {
  mouse,
  trackpad,
  touchscreen,
  stylus,
  unknown,
}

/// Abstract interface for platform-specific input device discovery.
///
/// NOT implemented in MVP. This interface exists to define the contract
/// for future platform-specific implementations.
abstract class InputAdapter {
  /// Discover connected input devices.
  Future<List<InputDeviceInfo>> discoverDevices();

  /// Get the capability status of input discovery on this platform.
  CapabilityStatus get discoveryCapability;
}

/// Stub adapter that reports input discovery as unavailable.
class UnsupportedInputAdapter implements InputAdapter {
  const UnsupportedInputAdapter();

  @override
  Future<List<InputDeviceInfo>> discoverDevices() async => [];

  @override
  CapabilityStatus get discoveryCapability => const CapabilityStatus(
        name: 'Input Device Discovery',
        level: CapabilityLevel.unsupported,
        description:
            'Input device discovery is not implemented in v1. '
            'This feature requires platform-specific native code and '
            'may need user permissions.',
        platformNote:
            'macOS: Accessibility/Input Monitoring permission may be required. '
            'Windows: Raw Input API. '
            'Linux/Wayland: XDG InputCapture portal (compositor-dependent).',
      );
}
