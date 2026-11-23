/// Display service for MacTouch.
///
/// Provides display information to the UI layer, abstracting the platform
/// adapter. Reports capabilities honestly and never fabricates data.
library;

import '../models/display_info.dart';
import '../models/capability_status.dart';
import '../platforms/display_adapter.dart';

/// Service that manages display enumeration and selection.
class DisplayService {
  DisplayAdapter _adapter;

  List<DisplayInfo> _displays = [];
  DisplayInfo? _selectedDisplay;
  bool _hasEnumerated = false;
  String? _lastError;

  DisplayService(this._adapter);

  /// Current display adapter.
  DisplayAdapter get adapter => _adapter;

  /// Change the display adapter (e.g. switch between live and simulated).
  void setAdapter(DisplayAdapter newAdapter) {
    _adapter = newAdapter;
  }

  /// Currently known displays.
  List<DisplayInfo> get displays => List.unmodifiable(_displays);

  /// The currently selected display (for coordinate mapping, calibration, etc.).
  DisplayInfo? get selectedDisplay => _selectedDisplay;

  /// Whether enumeration has been attempted.
  bool get hasEnumerated => _hasEnumerated;

  /// Last error message, if any.
  String? get lastError => _lastError;

  /// Display enumeration capability status.
  CapabilityStatus get capability => _adapter.enumerationCapability;

  /// Enumerate displays from the platform adapter.
  ///
  /// Returns true if enumeration succeeded and found at least one display.
  Future<bool> enumerate() async {
    _hasEnumerated = true;
    try {
      final result = await _adapter.enumerateDisplays();
      _displays = result.displays;
      _lastError = result.success ? null : result.message;

      // Auto-select primary display, or first available.
      if (_displays.isNotEmpty) {
        _selectedDisplay = _displays.firstWhere(
          (d) => d.isPrimary,
          orElse: () => _displays.first,
        );
      } else {
        _selectedDisplay = null;
      }

      return result.success && _displays.isNotEmpty;
    } catch (e) {
      _lastError = 'Display enumeration failed: $e';
      _displays = [];
      _selectedDisplay = null;
      return false;
    }
  }

  /// Select a display by index.
  bool selectDisplay(int index) {
    if (index < 0 || index >= _displays.length) return false;
    _selectedDisplay = _displays[index];
    return true;
  }

  /// Select a display by ID.
  bool selectDisplayById(String id) {
    final display = _displays.where((d) => d.id == id).firstOrNull;
    if (display == null) return false;
    _selectedDisplay = display;
    return true;
  }
}
