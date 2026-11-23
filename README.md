# MacTouch

**MacTouch** is an honest desktop utility for display inspection, coordinate visualization, and calibration-data management built with Flutter and Dart.

It provides deterministic coordinate mapping between desktop logical points, physical pixels, and normalized display coordinates, interactive quadrant visualization, a movable pointer simulator, and an affine calibration transform solver.

---

## Key Features

- **Smartphone Touch Digitizer (iPhone / Android)**:
  - Turns any iPhone or Android phone into a real-time, low-latency touchscreen controller for your MacBook over local Wi-Fi.
  - **Zero app installation on phone**: Phone connects directly via built-in local web server and WebSockets in Safari or Chrome.
  - **Dual Touch Modes**:
    - *Trackpad Mode*: Smooth cursor gliding, tap-to-click, and two-finger scrolling.
    - *Direct Screen Mode*: Maps phone touch coordinates 1:1 to MacBook display coordinates.
  - **Native macOS CoreGraphics Bridge**: Ultra-low-latency C helper for moving the desktop cursor and synthesizing clicks.
- **Display Coordinate Engine**:
  - Pure-Dart math for normalized coordinates ($u, v \in [0, 1]$) relative to display bounds.
  - Native support for negative desktop origins (e.g., multi-monitor setups with secondary displays to the left or top).
  - Explicit named coordinate spaces: Logical points, Physical pixels, Normalized coordinates, and Desktop-global coordinates.
- **Quadrant Visualization**:
  - Deterministic 4-quadrant layout with explicit midpoint boundary ownership ($u = 0.5, v = 0.5 \to \text{Q4}$).
  - Live quadrant highlighting and monospace coordinate readouts.
- **Pointer Simulator & In-App Pointer Events**:
  - Draggable simulated pointer reticle with normalized sliders and quadrant preset jumps.
  - In-app mouse pointer tracking active only when the window is focused (no global hooks or snooping).
- **Affine Calibration Engine**:
  - Solves $x' = ax + by + c, \: y' = dx + ey + f$ via least-squares normal equations.
  - Rejects degenerate inputs (fewer than 3 points, collinear points).
  - Reports RMS residual error and maximum residual error.
  - Interactive transform tester for arbitrary points.
- **Versioned Local JSON Storage**:
  - Saves calibration profiles per display without cloud or telemetry dependencies.
  - Default path: `~/.mactouch/profiles.v1.json`.

---

## Product Truth & Scope

1. **A stock MacBook display is NOT a touchscreen**. MacTouch makes no claim of detecting physical screen touch without dedicated external touch hardware.
2. **On-screen targets are visual prompts, not contact sensors**. Calibration samples in v1 are manually entered or simulated.
3. **In-app events only**. No global keyboard or mouse hooks. No OS cursor injection.
4. **Honest capability matrix**: Platform capabilities report accurate statuses (`supported`, `partial`, `unsupported`, `permissionRequired`) rather than fabricating OS metrics.

---

## Project Structure

```
mactouch/
├── lib/
│   ├── main.dart                          # App entry point & service initialization
│   ├── app.dart                           # Top-level MaterialApp & NavigationRail shell
│   ├── core/
│   │   ├── coordinates/                   # CoordinatePoint, NormalizedPoint, DisplayBounds, CoordinateMapper
│   │   ├── regions/                       # Quadrant enum, boundary conventions, RegionMap
│   │   └── calibration/                   # AffineCalibrator, least-squares normal equations, error metrics
│   ├── models/                            # CapabilityStatus, DisplayInfo, CalibrationProfile
│   ├── platforms/                         # DisplayAdapter, FlutterWindowDisplayAdapter, SimulatedDisplayAdapter
│   ├── services/                          # DisplayService, ProfileStore (versioned local JSON)
│   ├── screens/
│   │   ├── dashboard/                     # Canvas, Quadrant overlay, Pointer simulator, Numeric readout
│   │   ├── calibration/                   # Sample entry, affine transform solver, test transform
│   │   └── settings/                      # Platform capability truth table, display adapter switcher
│   └── widgets/                           # Reusable UI cards, overlays, and badges
├── test/
│   ├── coordinate_test.dart               # Unit tests for coordinates, negative origins, boundaries
│   ├── calibration_test.dart              # Unit tests for affine transform, collinearity, JSON store
│   └── widget_test.dart                   # Widget tests for shell, canvas, quadrants, navigation
├── docs/
│   ├── architecture.md                    # In-depth system architecture & math formulas
│   ├── platform-capabilities.md           # OS capability matrix & permission realities
│   └── limitations.md                     # Hardware truth & non-goals
└── pubspec.yaml
```

---

## Getting Started: How to Run

### Prerequisites
- **Flutter SDK**: 3.50+ (or compatible Dart 3.14+).
- **macOS Target**: Xcode or Command Line Tools.
- **Windows Target**: Visual Studio with "Desktop development with C++".
- **Linux Target**: Clang, CMake, GTK development headers (`pkg-config`, `libgtk-3-dev`).

### 1. Verify Flutter Environment
```bash
flutter doctor
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run the App
- **macOS Desktop**:
  ```bash
  flutter run -d macos
  ```
- **Windows Desktop**:
  ```bash
  flutter run -d windows
  ```
- **Linux Desktop**:
  ```bash
  flutter run -d linux
  ```
- **Chrome / Web (Preview)**:
  ```bash
  flutter run -d chrome
  ```

### 4. Run Automated Tests & Static Analysis
```bash
# Run unit & widget tests
flutter test

# Run Dart static analyzer
flutter analyze
```

---

## Important Things to Take Care Of

1. **Xcode Setup on macOS**:
   If building natively for macOS desktop using `flutter run -d macos`, ensure full Xcode or the macOS developer command line tools are configured (`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` if full Xcode is installed).
2. **Display Discovery Mode**:
   By default, MacTouch uses `FlutterWindowDisplayAdapter` which reads the active application window bounds via Flutter's `PlatformDispatcher`. You can toggle to `Simulated Multi-Display Adapter` in the **Settings** screen to inspect and test multi-monitor topology with negative desktop origins.
3. **Local JSON Permissions**:
   Calibration profiles are stored in `~/.mactouch/profiles.v1.json`. Ensure the user has write permissions in their user home directory.
4. **Platform-Specific Limitations**:
   Read [docs/platform-capabilities.md](file:///Users/arshmishra/Desktop/work/project-general/mactouch/docs/platform-capabilities.md) and [docs/limitations.md](file:///Users/arshmishra/Desktop/work/project-general/mactouch/docs/limitations.md) for detailed explanations on OS security boundaries.
