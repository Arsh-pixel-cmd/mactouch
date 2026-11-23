import 'dart:io';

/// Service that controls macOS desktop mouse cursor and clicks
/// via the high-performance native CoreGraphics helper binary.
class SystemCursorService {
  Process? _process;
  bool _isEnabled = false;
  bool _isAvailable = false;

  SystemCursorService() {
    _checkAvailability();
  }

  bool get isEnabled => _isEnabled;
  bool get isAvailable => _isAvailable;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (_isEnabled && _process == null) {
      _startBridge();
    } else if (!_isEnabled && _process != null) {
      _stopBridge();
    }
  }

  File? _findBinary() {
    final candidates = [
      File('bin/cursor_bridge'),
      File('${Platform.resolvedExecutable.replaceAll(RegExp(r'/[^/]+$'), '')}/bin/cursor_bridge'),
      File('${Platform.resolvedExecutable.replaceAll(RegExp(r'/[^/]+$'), '')}/cursor_bridge'),
    ];
    for (final f in candidates) {
      if (f.existsSync()) return f;
    }
    return null;
  }

  void _checkAvailability() {
    if (!Platform.isMacOS) {
      _isAvailable = false;
      return;
    }
    _isAvailable = _findBinary() != null;
  }

  Future<void> _startBridge() async {
    try {
      final binary = _findBinary();
      if (binary == null) {
        _isAvailable = false;
        return;
      }
      _process = await Process.start(binary.path, []);
      _isAvailable = true;
    } catch (e) {
      _isAvailable = false;
    }
  }

  void _stopBridge() {
    try {
      _process?.stdin.writeln('q');
      _process?.kill();
    } catch (_) {}
    _process = null;
  }

  /// Move mouse cursor to absolute screen coordinates (x, y).
  void moveTo(double x, double y) {
    if (!_isEnabled || _process == null) return;
    try {
      _process!.stdin.writeln('m $x $y');
    } catch (_) {}
  }

  /// Move mouse cursor relative to current position (dx, dy).
  void moveRelative(double dx, double dy) {
    if (!_isEnabled || _process == null) return;
    try {
      _process!.stdin.writeln('r $dx $dy');
    } catch (_) {}
  }

  /// Perform a left mouse click.
  void click() {
    if (!_isEnabled || _process == null) return;
    try {
      _process!.stdin.writeln('c');
    } catch (_) {}
  }

  /// Perform a right mouse click (context menu).
  void rightClick() {
    if (!_isEnabled || _process == null) return;
    try {
      _process!.stdin.writeln('k');
    } catch (_) {}
  }

  /// Left mouse button down (for starting drag).
  void mouseDown() {
    if (!_isEnabled || _process == null) return;
    try {
      _process!.stdin.writeln('d');
    } catch (_) {}
  }

  /// Left mouse button up (for ending drag).
  void mouseUp() {
    if (!_isEnabled || _process == null) return;
    try {
      _process!.stdin.writeln('u');
    } catch (_) {}
  }

  /// Scroll wheel delta.
  void scroll(int dy) {
    if (!_isEnabled || _process == null) return;
    try {
      _process!.stdin.writeln('s $dy');
    } catch (_) {}
  }

  void dispose() {
    _stopBridge();
  }
}
