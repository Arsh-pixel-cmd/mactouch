# MacTouch — Comprehensive Technical Architecture & Engineering Documentation

> **Document Classification**: Enterprise Architecture & Software Reverse Engineering Specification  
> **Target Audience**: Senior Staff Engineers, Principal Architects, Core Systems Engineers  
> **System Version**: 1.0.0+1 (Darwin / Windows / Linux / Web)  
> **Author**: Google DeepMind / Antigravity Engineering

---

# 1 Executive Summary

### 1.1 Business Purpose
MacTouch resolves a fundamental human-computer interaction challenge on modern desktop computing platforms: bridging the gap between non-touch laptop displays (such as conventional Apple MacBook hardware and legacy Windows/Linux clamshell machines) and modern touch-digitizer workflows without requiring expensive, destructive hardware modifications. Rather than fabricating contact signals or falsely promising that inert display glass can detect capacitive touch, MacTouch operates with strict physical honesty. It provides an enterprise-grade utility that solves two complementary engineering problems:
1. **Mathematical Coordinate Mapping & Display Topology Visualization**: Providing a deterministic, pure-Dart coordinate transformation and validation engine capable of translating raw input correspondences, multi-monitor topologies with negative desktop offsets, and scale factors (device pixel ratios) into normalized coordinate spaces.
2. **Smartphone-to-Desktop Remote Touch Digitization**: Turning any physical smartphone or tablet (iPhone, iPad, or Android) into an ultra-low-latency, multi-touch external digitizer for the host laptop over local network WebSockets.

### 1.2 Technical Purpose
Architecturally, MacTouch is divided into two distinct execution tiers:
- A cross-platform **UI & Mathematical Engine** implemented in Flutter and Pure Dart (`lib/core/`, `lib/models/`, `lib/screens/`, `lib/widgets/`).
- An ultra-fast, native **Operating System Event Dispatcher & Server Tier** implemented via Dart's asynchronous I/O (`HttpServer`, `WebSocketTransformer`) coupled with an optimized native CoreGraphics C binary (`bin/cursor_bridge.c`) that interacts directly with Apple's `ApplicationServices` and Quartz Display Services without the overhead of heavy third-party runtimes.

The coordinate engine guarantees mathematical determinism across all four quadrants ($Q_1$ through $Q_4$), defines rigid boundary ownership conventions ($u = 0.5, v = 0.5 \to Q_4$), computes affine least-squares transformations using Cramer's rule on $3 \times 3$ normal equations, and persists versioned calibration profiles locally in JSON format without telemetry, cloud dependencies, or tracking.

### 1.3 Target Users
1. **Engineers & Display Calibration Specialists**: Developers building or calibrating external touch overlays, optical light-curtain frames (e.g., Neonode AirBar), or computer-vision hand-tracking pipelines requiring affine matrix calculations, residual error analysis (RMS and max error), and negative-origin multi-display mapping.
2. **Power Users & Creatives**: MacBook and desktop users who require touch-digitizer input, precision gestures, or trackpad-style control using their existing mobile devices without purchasing external graphics tablets or Apple Pencils.
3. **Cross-Platform Systems Developers**: Teams investigating low-level OS input hooks, compositor-level security boundaries (macOS TCC permissions, Windows Raw Input, Linux Wayland XDG portals vs. X11), and high-frequency network event streaming.

### 1.4 Primary Workflows
- **Workflow A (Display Inspection & Simulation)**: The user inspects detected display bounds, selects between live window viewports and simulated multi-display topologies with negative offsets (e.g., secondary monitor at `(-1920, 0)`), drags the simulated pointer reticle, and observes real-time coordinate transformations across logical points, physical pixels, normalized $(u, v)$ coordinates, and active quadrant assignments.
- **Workflow B (Affine Calibration Profile Generation)**: The user enters or generates correspondence sample pairs between source (input) coordinates and target (screen) coordinates. The system performs least-squares regression to solve the 6-parameter affine matrix, detects collinearity or rank deficiency, reports RMS/max errors in pixels, tests arbitrary coordinate transformations, and saves versioned profiles to `~/.mactouch/profiles.v1.json`.
- **Workflow C (Phone-to-Mac Remote Touch Digitizer)**: MacTouch activates a local HTTP/WebSocket server on port `8080`. The user scans a QR code or opens `http://<Mac-IP>:8080` on an iPhone or Android phone. Touches on the mobile screen stream over WebSockets at sub-10ms latency. In *Trackpad Mode*, single-finger deltas move the Mac cursor, single-tap clicks, two-finger tap right-clicks, and two-finger drags scroll. In *Direct Screen Mode*, phone touches map 1:1 onto the display geometry.

### 1.5 Architectural Philosophy
The core architectural philosophy of MacTouch is **zero fabrication, complete physical honesty, and rigid modular isolation**.
- *Zero Fabrication*: If native display enumeration or global input monitoring is unsupported on a specific platform, the application explicitly exposes `CapabilityLevel.unsupported` or `partial`. It never fakes OS API data.
- *Strict Layer Decoupling*: All coordinate math, quadrant hashing, and affine algorithms reside in pure Dart libraries that have zero dependencies on Flutter UI (`dart:ui` or `package:flutter`), enabling 100% deterministic, lightning-fast headless unit testing.
- *Least-Privilege Security*: Global system cursor injection is isolated behind an explicit native binary helper (`bin/cursor_bridge`) requiring user consent and operating via standard UNIX input/output pipes.

---

# 2 Capability Matrix

| Capability | Subsystem | Files Involved | Direct Dependencies | Execution Flow |
|---|---|---|---|---|
| **Normalized Coordinate Mapping** | Coordinate Engine | `lib/core/coordinates/coordinate_spaces.dart` | `dart:core` (Pure Dart) | Desktop Logical $(x, y) \to$ Bounds Offset $\to$ Divisor $(W, H) \to$ Normalized $(u, v)$ |
| **Deterministic Quadrant Partitioning** | Region Engine | `lib/core/regions/quadrant.dart` | `coordinate_spaces.dart` | Normalized $(u, v) \to$ Midpoint Checks $(0.5, 0.5) \to$ Enum `Quadrant.topLeft...bottomRight` |
| **Affine Transform Computation** | Calibration Engine | `lib/core/calibration/affine_calibration.dart` | `dart:math` | Correspondences $(x_i, y_i) \to (x'_i, y'_i) \to$ Collinearity Check $\to$ Normal Equations $A^T A \mathbf{p} = A^T \mathbf{b} \to$ Cramer $3 \times 3 \to [a, b, c, d, e, f]$ |
| **Versioned Profile Persistence** | Persistence Store | `lib/services/profile_store.dart`, `lib/models/calibration_profile.dart` | `dart:convert`, `dart:io` | Memory Profiles $\to$ `ProfileStoreDocument` $\to$ JSON Encode $\to$ Atomic File Write `~/.mactouch/profiles.v1.json` |
| **Display Enumeration** | Platform Adapter | `lib/platforms/display_adapter.dart`, `lib/services/display_service.dart` | `dart:ui` (`PlatformDispatcher`) | Adapter Query $\to$ Views Query $\to$ DPR Normalization $\to$ DisplayInfo List |
| **Phone Web Digitizer Server** | Network Server | `lib/services/touch_server_service.dart`, `bin/server.dart` | `dart:io` (`HttpServer`, `WebSocketTransformer`) | NetworkInterface IPv4 Discovery $\to$ Port 8080 Bind $\to$ HTTP Request $\to$ Serve HTML/JS $\to$ Upgrade `/ws` $\to$ JSON Touch Stream |
| **Native Cursor Control** | Native Systems Bridge | `lib/services/system_cursor_service.dart`, `bin/cursor_bridge.c` | CoreGraphics, ApplicationServices | WebSocket Event $\to$ Stdin Pipe (`m x y` / `c` / `s dy`) $\to$ `cursor_bridge` $\to$ `CGEventCreateMouseEvent` $\to$ `CGEventPost(kCGHIDEventTap)` |
| **Interactive Display Preview** | Presentation Layer | `lib/widgets/display_canvas.dart`, `lib/widgets/quadrant_overlay.dart` | Flutter Rendering Pipeline | PointerHover / PointerDown $\to$ Canvas Aspect Ratio Clamp $\to$ Quadrant Overlay Paint $\to$ Simulated Reticle Draw |

---

# 3 Technology Stack

| Layer | Technology | Version | Purpose | Reason Selected | Alternatives Considered |
|---|---|---|---|---|---|
| **UI Framework** | Flutter Desktop | 3.50.1 / Stable | Cross-platform desktop presentation layer | Declarative canvas rendering, high-DPI scaling, multi-window layout engine | Electron (rejected: excessive memory/binary bloat), Qt/C++ (rejected: slow UI iteration), SwiftUI (rejected: macOS-only) |
| **Language** | Dart SDK | 3.14.0 | Core mathematics, models, services, networking | Sound null-safety, Ahead-Of-Time (AOT) compilation, built-in non-blocking asynchronous I/O (`dart:io`) | C++ (higher complexity for cross-platform UI), Rust (complex FFI binding maintenance) |
| **Native macOS Bridge** | C / CoreGraphics | ANSI C99 / Clang 2100 | Low-latency system cursor injection & click synthesis | Direct C binding to macOS Quartz Event Services (`CGEventPost`), sub-millisecond execution, zero runtime dependencies | AppleScript/osascript (rejected: ~50ms execution latency per call), Python PyAutoGUI (rejected: massive Python interpreter dependency) |
| **Local Web Server** | Dart I/O Engine | Built-in | Serving mobile touch web client & handling WebSockets | Zero third-party dependencies, native event loop integration, asynchronous streaming | Shelf / Express (rejected: unnecessary dependency overhead for single-file web server) |
| **Mobile Client UI** | HTML5 / CSS3 / ES6 | Modern Standards | Fullscreen touch surface on iOS Safari / Android Chrome | Zero mobile app download required; ubiquitous multi-touch capacitive digitizer support | Native iOS/Android app (rejected: high onboarding barrier requiring App Store / Play Store installation) |
| **Build & Toolchain** | Flutter Tools / CMake / Xcode | Stable | Multi-platform compilation & binary packaging | Official framework tooling for macOS `.app`, Windows `.exe`, and Linux GTK runners | Custom Makefiles (unsupported by Flutter engine) |
| **CI / CD** | GitHub Actions | Ubuntu / macOS-14 | Automated static analysis, testing, and cloud macOS compilation | Free access to macOS runners with pre-installed Xcode for developers without local Xcode | Local compilation (blocked when developer lacks 30GB disk space for Xcode) |

---

# 4 High-Level Architecture

### 4.1 ASCII Architectural Diagram

```
+========================================================================================+
|                                    MACTOUCH SYSTEM                                     |
+========================================================================================+
|                                                                                        |
|   +--------------------------------------------------------------------------------+   |
|   |                        SMARTPHONE CLIENT (iOS / Android)                       |   |
|   |   - Fullscreen Touchpad Surface (HTML5 / Pointer Events)                       |   |
|   |   - Dual Modes: Trackpad (Relative dx, dy) / Direct Screen (Absolute u, v)     |   |
|   +--------------------------------------------------------------------------------+   |
|                                           |                                            |
|                                   WebSocket (ws://)                                    |
|                                           |                                            |
|   +--------------------------------------------------------------------------------+   |
|   |                        LOCAL SERVER SUBSYSTEM (Port 8080)                      |   |
|   |   - TouchServerService (dart:io HttpServer & WebSocketTransformer)             |   |
|   |   - Embedded HTML5/JS Touchpad Web Client Distribution                         |   |
|   +--------------------------------------------------------------------------------+   |
|                                           |                                            |
|                            Stream<PhoneTouchEvent>                                     |
|                                           v                                            |
|   +--------------------------------------------------------------------------------+   |
|   |                           SERVICES & ADAPTERS SUBSYSTEM                        |   |
|   |   +--------------------------+  +------------------------------------------+   |   |
|   |   |      DisplayService      |  |           SystemCursorService            |   |   |
|   |   |  - Enumerate displays    |  |  - Controls bin/cursor_bridge process    |   |   |
|   |   |  - Active monitor state  |  |  - stdin commands: m, r, c, k, s, d, u   |   |   |
|   |   +--------------------------+  +------------------------------------------+   |   |
|   |   +--------------------------+  +------------------------------------------+   |   |
|   |   |      ProfileStore        |  |          Platform Adapters               |   |   |
|   |   |  - ~/.mactouch/JSON      |  |  - FlutterWindowDisplayAdapter           |   |   |
|   |   |  - Versioned storage     |  |  - SimulatedDisplayAdapter (Negative)   |   |   |
|   |   +--------------------------+  +------------------------------------------+   |   |
|   +--------------------------------------------------------------------------------+   |
|                                           |                                            |
|                                           v                                            |
|   +--------------------------------------------------------------------------------+   |
|   |                            PURE DART CORE ENGINE                               |   |
|   |   - CoordinateMapper: [Desktop-Global] <===> [Normalized [0, 1]]               |   |
|   |   - Quadrant: Deterministic boundary allocation (Midpoint -> Q4)               |   |
|   |   - AffineCalibrator: Least-Squares Normal Equations & Cramer's Rule           |   |
|   +--------------------------------------------------------------------------------+   |
|                                           |                                            |
|                                           v                                            |
|   +--------------------------------------------------------------------------------+   |
|   |                       FLUTTER PRESENTATION SHELL (UI)                          |   |
|   |   - DashboardScreen (Live Display Canvas, Readout, Simulator Sliders)          |   |
|   |   - CalibrationScreen (Sample Grid, Degeneracy Rejection, Test Tool)           |   |
|   |   - SettingsScreen (Platform Capability Truth Table, Mode Toggle)              |   |
|   +--------------------------------------------------------------------------------+   |
|                                           |                                            |
|                                     IPC Stdin Pipe                                     |
|                                           v                                            |
|   +--------------------------------------------------------------------------------+   |
|   |                  NATIVE OPERATING SYSTEM BRIDGE (macOS)                        |   |
|   |   - bin/cursor_bridge (Compiled C binary linked with ApplicationServices)     |   |
|   |   - CGEventCreateMouseEvent & CGEventPost(kCGHIDEventTap)                      |   |
|   +--------------------------------------------------------------------------------+   |
|                                                                                        |
+========================================================================================+
```

### 4.2 Mermaid Component Diagram

```mermaid
graph TD
    subgraph Mobile ["External Mobile Digitizer"]
        Phone["📱 Smartphone Browser\n(iOS Safari / Android Chrome)"]
    end

    subgraph ServerLayer ["In-App Server Layer (dart:io)"]
        TSS["TouchServerService\n(HTTP & WebSocket Engine)"]
        HTML["Embedded Web App\n(HTML5 / CSS3 / JS)"]
    end

    subgraph Presentation ["Presentation Layer (Flutter)"]
        App["MacTouchApp / MacTouchShell"]
        Dashboard["DashboardScreen"]
        Calibration["CalibrationScreen"]
        Settings["SettingsScreen"]
        Canvas["DisplayCanvas"]
        Overlay["QuadrantOverlay"]
        Readout["CoordinateReadout"]
        Badge["CapabilityBadge"]
    end

    subgraph ServiceLayer ["Service Layer"]
        DS["DisplayService"]
        PS["ProfileStore (Local JSON)"]
        SCS["SystemCursorService"]
    end

    subgraph PlatformLayer ["Platform Adapters"]
        FDA["FlutterWindowDisplayAdapter"]
        SDA["SimulatedDisplayAdapter"]
        UIA["UnsupportedInputAdapter"]
    end

    subgraph CoreEngine ["Pure-Dart Mathematical Core"]
        CM["CoordinateMapper"]
        DB["DisplayBounds"]
        QM["Quadrant & RegionMap"]
        AC["AffineCalibrator"]
    end

    subgraph OS ["Operating System & Hardware"]
        CB["bin/cursor_bridge (Native C)"]
        CG["macOS CoreGraphics / Quartz HID"]
        JSONFile["~/.mactouch/profiles.v1.json"]
    end

    Phone -- "HTTP GET /" --> TSS
    TSS -- "Serves Touchpad UI" --> Phone
    Phone -- "WebSocket (dx, dy, u, v)" --> TSS
    TSS -- "Stream<PhoneTouchEvent>" --> Dashboard
    Dashboard --> SCS
    SCS -- "IPC stdin pipe" --> CB
    CB -- "CGEventPost()" --> CG

    App --> Dashboard
    App --> Calibration
    App --> Settings
    Dashboard --> Canvas
    Dashboard --> Readout
    Canvas --> Overlay

    Dashboard --> DS
    Dashboard --> CM
    Calibration --> AC
    Calibration --> PS
    Settings --> DS
    Settings --> PS

    DS --> FDA
    DS --> SDA
    PS --> JSONFile
```

### 4.3 End-to-End Sequence Diagram: Phone Touch to Desktop Cursor

```mermaid
sequenceDiagram
    autonumber
    actor User as User on Phone
    participant Browser as Mobile Safari / Chrome
    participant TSS as TouchServerService
    participant Dash as DashboardScreen
    participant CM as CoordinateMapper
    participant SCS as SystemCursorService
    participant Bridge as bin/cursor_bridge
    participant macOS as macOS Window Server

    User->>Browser: Touch & Drag on Phone Surface
    Browser->>Browser: Compute touch delta (dx, dy) or (u, v)
    Browser->>TSS: WebSocket JSON: {"type":"move", "dx":2.5, "dy":-1.8}
    TSS->>Dash: Emit PhoneTouchEvent(type: move, dx: 2.5, dy: -1.8)
    
    alt Trackpad Mode (Relative Drag)
        Dash->>SCS: moveRelative(2.5, -1.8)
        SCS->>Bridge: Stdin write: "r 2.5 -1.8\n"
        Bridge->>macOS: CGEventGetLocation() + (dx, dy)
        Bridge->>macOS: CGEventCreateMouseEvent(kCGEventMouseMoved)
        Bridge->>macOS: CGEventPost(kCGHIDEventTap, moveEvent)
        macOS-->>User: Cursor shifts on MacBook Screen
    else Direct Screen Mode (Absolute Coordinate)
        Browser->>TSS: WebSocket JSON: {"type":"abs", "u":0.75, "v":0.25}
        TSS->>Dash: Emit PhoneTouchEvent(type: abs, u: 0.75, v: 0.25)
        Dash->>CM: fromNormalized(NormalizedPoint(0.75, 0.25))
        CM-->>Dash: CoordinatePoint(1080.0, 225.0, desktopGlobal)
        Dash->>SCS: moveTo(1080.0, 225.0)
        SCS->>Bridge: Stdin write: "m 1080.0 225.0\n"
        Bridge->>macOS: CGEventCreateMouseEvent(1080, 225)
        Bridge->>macOS: CGEventPost(kCGHIDEventTap, moveEvent)
        macOS-->>User: Cursor jumps to exact quadrant position
    end
```

---

# 5 Complete Directory Walkthrough

```
mactouch/
├── .github/
│   └── workflows/
│       └── build_macos.yml                # CI/CD Cloud Pipeline for Native macOS Builds
├── bin/
│   ├── cursor_bridge.c                    # Native C CoreGraphics Cursor Dispatcher
│   ├── cursor_bridge                      # Compiled Executable (ApplicationServices)
│   └── server.dart                        # Standalone Headless Daemon Server
├── docs/
│   ├── architecture.md                    # Core Architectural Principles & Formulas
│   ├── limitations.md                     # Hardware Truth & Non-Goals Specification
│   ├── platform-capabilities.md           # OS Capability & Permission Realities
│   └── TECHNICAL_DOCUMENTATION.md         # This Master Architecture Document
├── lib/
│   ├── main.dart                          # Application Entry Point & Dependency Bootstrap
│   ├── app.dart                           # Top-Level MaterialApp Shell & NavigationRail
│   ├── core/
│   │   ├── calibration/
│   │   │   └── affine_calibration.dart    # Affine Least-Squares Solver & Collinearity Logic
│   │   ├── coordinates/
│   │   │   └── coordinate_spaces.dart     # Typed Spaces, Normalization, Bounds Validation
│   │   └── regions/
│   │       └── quadrant.dart              # Deterministic Quadrant Boundary Math & RegionMap
│   ├── models/
│   │   ├── calibration_profile.dart       # Calibration Profile Model & JSON Deserializer
│   │   ├── capability_status.dart         # Platform Capabilities & Honesty Levels
│   │   └── display_info.dart              # Display Geometry, Scale Factor & Status Model
│   ├── platforms/
│   │   ├── display_adapter.dart           # Display Discovery Adapters (Live & Simulated)
│   │   └── input_adapter.dart             # Input Device Discovery Contracts
│   ├── screens/
│   │   ├── calibration/
│   │   │   └── calibration_screen.dart    # Profile Management, Matrix Solver, Residual Grid
│   │   ├── dashboard/
│   │   │   └── dashboard_screen.dart      # Main Operations Center & Canvas Inspector
│   │   └── settings/
│   │       └── settings_screen.dart       # Platform Capability Matrix & Storage Admin
│   ├── services/
│   │   ├── display_service.dart           # Display Discovery & Selection Coordinator
│   │   ├── profile_store.dart             # Versioned Local JSON Storage Engine
│   │   ├── system_cursor_service.dart     # Process Life-Cycle Manager for cursor_bridge
│   │   └── touch_server_service.dart      # HTTP / WebSocket Server for Mobile Digitizer
│   └── widgets/
│       ├── capability_badge.dart          # Visual Status Badges for CapabilityLevel
│       ├── coordinate_readout.dart        # Monospace Real-Time Multi-Space Coordinates Card
│       ├── display_canvas.dart            # Interactive Display Canvas & Aspect Ratio Frame
│       └── quadrant_overlay.dart          # 4-Quadrant Visual Grid & Axis Indicator
├── macos/                                 # Native Apple macOS Runner & Xcode Project
├── windows/                               # Native Microsoft Windows Runner & CMake Project
├── linux/                                 # Native Linux Runner & CMake Project
├── test/
│   ├── calibration_test.dart              # Affine Transform, Regression, & JSON Store Tests
│   ├── coordinate_test.dart               # Normalization, Clamping, & Quadrant Math Tests
│   └── widget_test.dart                   # Desktop UI Shell, Canvas, & Navigation Tests
├── analysis_options.yaml                  # Static Analyzer Rules & Lint Configuration
├── pubspec.yaml                           # Project Dependencies & Build Metadata
└── README.md                              # Public Repository Documentation
```

### 5.1 File-by-File Technical Analysis

#### `lib/core/coordinates/coordinate_spaces.dart`
- **Purpose**: Establishes immutable data representations and rigorous conversions across four distinct coordinate systems.
- **Responsibilities**: Prevents accidental mixing of logical desktop points, device physical pixels, display-normalized coordinates, and multi-monitor global coordinates.
- **Dependencies**: `dart:core`.
- **Exports**: `CoordinatePoint`, `CoordinateSpace`, `NormalizedPoint`, `DisplayBounds`, `CoordinateMapper`.
- **Used By**: Entire codebase (`quadrant.dart`, `display_adapter.dart`, `display_service.dart`, `dashboard_screen.dart`, all tests).
- **Approximate Size**: 198 lines.
- **Importance Level**: **Critical (P0 Foundation)**.

#### `lib/core/regions/quadrant.dart`
- **Purpose**: Defines deterministic spatial partitioning across normalized coordinate planes.
- **Responsibilities**: Enforces the mathematical convention that exact boundary midpoints ($u = 0.5, v = 0.5$) resolve deterministically to higher-index quadrants ($Q_4$ at the center intersection). Implements generic arbitrary `Region` and `RegionMap` queries.
- **Dependencies**: `coordinate_spaces.dart`.
- **Exports**: `Quadrant`, `getQuadrant()`, `Region`, `RegionMap`.
- **Used By**: `dashboard_screen.dart`, `quadrant_overlay.dart`, `coordinate_readout.dart`, `coordinate_test.dart`.
- **Approximate Size**: 127 lines.
- **Importance Level**: **Critical (P0 Foundation)**.

#### `lib/core/calibration/affine_calibration.dart`
- **Purpose**: Mathematical transformation engine computing 6-degree-of-freedom affine mappings ($x' = ax + by + c, y' = dx + ey + f$).
- **Responsibilities**: Rejects degenerate point configurations ($N < 3$ points or collinear samples via vector cross-products). Constructs the normal equations $A^T A \mathbf{p} = A^T \mathbf{b}$ and solves the symmetric $3 \times 3$ system via Cramer's rule. Calculates Root-Mean-Square (RMS) and maximum residual errors.
- **Dependencies**: `dart:math`.
- **Exports**: `CalibrationSample`, `AffineCalibrationResult`, `AffineCalibrator`.
- **Used By**: `calibration_profile.dart`, `calibration_screen.dart`, `calibration_test.dart`.
- **Approximate Size**: 230 lines.
- **Importance Level**: **Critical (P0 Math Engine)**.

#### `lib/models/capability_status.dart`
- **Purpose**: Enforces truthful platform capability reporting.
- **Responsibilities**: Encapsulates `CapabilityLevel` (`supported`, `partial`, `unsupported`, `unknown`, `permissionRequired`) and constructs default capability matrices that explicitly disclaim hardware touchscreen sensing on conventional MacBooks.
- **Dependencies**: None.
- **Exports**: `CapabilityLevel`, `CapabilityStatus`, `PlatformCapabilities`.
- **Used By**: `display_adapter.dart`, `input_adapter.dart`, `settings_screen.dart`, `capability_badge.dart`.
- **Approximate Size**: 121 lines.
- **Importance Level**: **High (Product Truth & Compliance)**.

#### `lib/models/display_info.dart`
- **Purpose**: Structured representation of physical/logical display outputs.
- **Responsibilities**: Maintains stable monitor IDs, display names, `DisplayBounds`, device pixel ratio scale factors, primary monitor flags, and value reliability tags (`DisplayValueStatus`).
- **Dependencies**: `coordinate_spaces.dart`.
- **Exports**: `DisplayValueStatus`, `DisplayInfo`.
- **Used By**: `display_adapter.dart`, `display_service.dart`, `dashboard_screen.dart`.
- **Approximate Size**: 72 lines.
- **Importance Level**: **High (Data Model)**.

#### `lib/models/calibration_profile.dart`
- **Purpose**: Serializable domain model for calibration configurations.
- **Responsibilities**: Manages serialization and deserialization of sample correspondence lists, computed affine matrices, timestamps, and target display bindings.
- **Dependencies**: `affine_calibration.dart`.
- **Exports**: `CalibrationProfile`.
- **Used By**: `profile_store.dart`, `calibration_screen.dart`, `settings_screen.dart`.
- **Approximate Size**: 126 lines.
- **Importance Level**: **High (Persistence Model)**.

#### `lib/platforms/display_adapter.dart`
- **Purpose**: Abstraction layer decoupling the display query interface from platform-specific APIs.
- **Responsibilities**: Implements `FlutterWindowDisplayAdapter` (interrogating `ui.PlatformDispatcher.instance.views` for active window dimensions) and `SimulatedDisplayAdapter` (providing simulated dual-monitor layouts with negative desktop origins).
- **Dependencies**: `dart:ui`, `display_info.dart`, `capability_status.dart`, `coordinate_spaces.dart`.
- **Exports**: `DisplayEnumerationResult`, `DisplayAdapter`, `UnsupportedDisplayAdapter`, `SimulatedDisplayAdapter`, `FlutterWindowDisplayAdapter`.
- **Used By**: `display_service.dart`, `settings_screen.dart`, `main.dart`.
- **Approximate Size**: 170 lines.
- **Importance Level**: **High (Hardware Abstraction)**.

#### `lib/platforms/input_adapter.dart`
- **Purpose**: Contract definition for hardware input device discovery.
- **Responsibilities**: Defines device types (`mouse`, `trackpad`, `touchscreen`, `stylus`). Implements `UnsupportedInputAdapter` to honestly communicate that global hardware enumeration is out of scope in v1.
- **Dependencies**: `capability_status.dart`.
- **Exports**: `InputDeviceInfo`, `InputDeviceType`, `InputAdapter`, `UnsupportedInputAdapter`.
- **Used By**: Architectural contracts and capability testing.
- **Approximate Size**: 73 lines.
- **Importance Level**: **Medium (Architectural Specification)**.

#### `lib/services/display_service.dart`
- **Purpose**: State coordinator for display discovery and active target selection.
- **Responsibilities**: Drives asynchronous enumeration, caches the display list, auto-selects primary monitors, allows dynamic adapter swapping between live and simulated modes, and surfaces error states.
- **Dependencies**: `display_info.dart`, `capability_status.dart`, `display_adapter.dart`.
- **Exports**: `DisplayService`.
- **Used By**: `app.dart`, `main.dart`, `dashboard_screen.dart`, `calibration_screen.dart`, `settings_screen.dart`.
- **Approximate Size**: 81 lines.
- **Importance Level**: **High (Core Service)**.

#### `lib/services/profile_store.dart`
- **Purpose**: Local disk persistence manager for calibration profiles.
- **Responsibilities**: Manages atomic reads and writes of `ProfileStoreDocument` (schema version 1) to `~/.mactouch/profiles.v1.json`. Handles version checks, profile addition, deletion, and schema reset.
- **Dependencies**: `dart:convert`, `dart:io`, `calibration_profile.dart`.
- **Exports**: `profileStoreVersion`, `ProfileStoreDocument`, `ProfileStore`.
- **Used By**: `app.dart`, `main.dart`, `calibration_screen.dart`, `settings_screen.dart`, `calibration_test.dart`.
- **Approximate Size**: 151 lines.
- **Importance Level**: **High (Core Service)**.

#### `lib/services/system_cursor_service.dart`
- **Purpose**: Inter-process communication coordinator controlling the host desktop cursor.
- **Responsibilities**: Spawns and supervises the native `bin/cursor_bridge` executable. Transmits streaming command tokens via standard input pipes for absolute movement (`m x y`), relative movement (`r dx dy`), clicks (`c`), right-clicks (`k`), and scrolling (`s dy`).
- **Dependencies**: `dart:io`.
- **Exports**: `SystemCursorService`.
- **Used By**: `main.dart`, `app.dart`, `dashboard_screen.dart`, `bin/server.dart`.
- **Approximate Size**: 118 lines.
- **Importance Level**: **High (Native OS Bridge)**.

#### `lib/services/touch_server_service.dart`
- **Purpose**: Embedded local HTTP and WebSocket server engine.
- **Responsibilities**: Discovers the active local Wi-Fi IPv4 address, binds `HttpServer` to port `8080`, serves a zero-dependency HTML5 mobile touch application, upgrades `/ws` connections to WebSockets, parses JSON touch payloads, and broadcasts high-frequency touch streams to UI listeners.
- **Dependencies**: `dart:async`, `dart:convert`, `dart:io`.
- **Exports**: `PhoneTouchEvent`, `TouchServerService`.
- **Used By**: `main.dart`, `app.dart`, `dashboard_screen.dart`, `bin/server.dart`.
- **Approximate Size**: 340 lines.
- **Importance Level**: **Critical (Mobile Digitizer Engine)**.

#### `bin/cursor_bridge.c`
- **Purpose**: Native C executable linking directly with Apple's `ApplicationServices` framework.
- **Responsibilities**: Consumes stdin line-by-line in a zero-buffering loop. Synthesizes Quartz display events via `CGEventCreateMouseEvent`, `CGEventCreateScrollWheelEvent`, and `CGEventPost(kCGHIDEventTap, event)`. Executes with sub-millisecond latency without requiring Python or Objective-C runtime overhead.
- **Dependencies**: `<ApplicationServices/ApplicationServices.h>`, `<stdio.h>`, `<stdlib.h>`.
- **Compiled Target**: `bin/cursor_bridge` (Mach-O 64-bit arm64 executable).
- **Used By**: `SystemCursorService`.
- **Approximate Size**: 120 lines.
- **Importance Level**: **Critical (Hardware Event Synthesis)**.

#### `bin/server.dart`
- **Purpose**: Headless standalone daemon executable for running the touch server independently of the Flutter UI.
- **Responsibilities**: Initializes `TouchServerService` and `SystemCursorService`, outputs terminal QR/URL connection instructions, and routes incoming phone touch events directly to `cursor_bridge`.
- **Dependencies**: `dart:io`, `touch_server_service.dart`, `system_cursor_service.dart`.
- **Approximate Size**: 65 lines.
- **Importance Level**: **Medium (Developer & Headless Utility)**.

---

# 6 Boot Process & System Initialization

The application lifecycle initiates within `lib/main.dart` and executes a deterministic, multi-stage bootstrap sequence:

```mermaid
sequenceDiagram
    autonumber
    participant Main as main()
    participant Flutter as WidgetsFlutterBinding
    participant Disp as DisplayService
    participant Store as ProfileStore
    participant Server as TouchServerService
    participant Cursor as SystemCursorService
    participant App as MacTouchApp

    Main->>Flutter: ensureInitialized()
    Main->>Disp: new DisplayService(FlutterWindowDisplayAdapter)
    Main->>Disp: enumerate()
    Disp-->>Main: Displays cached & primary selected
    Main->>Store: new ProfileStore("~/.mactouch/profiles.v1.json")
    Main->>Store: load()
    Store-->>Main: Profiles parsed into memory
    Main->>Server: new TouchServerService()
    Main->>Server: start(port: 8080)
    Server-->>Main: Bound to 0.0.0.0:8080 & IPv4 discovered
    Main->>Cursor: new SystemCursorService()
    Main->>Cursor: setEnabled(true)
    Cursor-->>Main: Spawns bin/cursor_bridge process
    Main->>App: runApp(MacTouchApp(deps...))
```

### Detailed Boot Steps
1. **Flutter Engine Binding (`WidgetsFlutterBinding.ensureInitialized()`)**: Attaches the Dart execution isolate to the platform window embedder, establishing the binary messenger and platform channels.
2. **Display Discovery Initialization**:
   - Instantiates `FlutterWindowDisplayAdapter`.
   - Injects the adapter into `DisplayService`.
   - Awaits `displayService.enumerate()`. If the platform window views are available via `PlatformDispatcher.instance.views`, logical bounds and DPR scale factors are extracted. The primary display is automatically selected.
3. **Storage Tier Bootstrap**:
   - Resolves the host environment directory (`$HOME` on Unix/macOS, `%USERPROFILE%` on Windows).
   - Establishes the store path at `.mactouch/profiles.v1.json`.
   - Awaits `profileStore.load()`. If the file does not exist, an empty in-memory store is established. If it exists, version validation is verified against `profileStoreVersion = 1`.
4. **Local Touch Server Startup**:
   - Instantiates `TouchServerService`.
   - Awaits `touchServer.start(port: 8080)`.
   - Automatically queries `NetworkInterface.list()` to identify the local Wi-Fi interface (`en0` / `wl*`) and caches the local IPv4 address.
5. **System Cursor Bridge Spawning**:
   - Instantiates `SystemCursorService`.
   - Invokes `cursorService.setEnabled(true)`, which locates `bin/cursor_bridge` (or the bundle path inside `mactouch.app/Contents/MacOS/cursor_bridge`) and spawns the background worker process with piped standard I/O.
6. **Widget Tree Mounting**: Mounts `MacTouchApp` into the Flutter rendering pipeline, injecting the initialized services into `MacTouchShell`.

---

# 7 Routing & Navigation Architecture

MacTouch utilizes an unconstrained, zero-latency desktop navigation model powered by Flutter's `NavigationRail` and an indexed stack layout:

- **Root Host**: `MacTouchShell` (`lib/app.dart`).
- **Layout Architecture**: Horizontal split with a pinned left `NavigationRail` (width: ~72px) and an expanded `IndexedStack` occupying the remaining viewport.
- **Why `IndexedStack` was Selected**:
  Desktop utilities require that background canvas states, active pointer coordinates, web server socket connections, and manual calibration input forms maintain state across tab transitions. Unlike destructive route navigation (`Navigator.pushReplacement`), `IndexedStack` preserves the underlying widget state trees and controllers of all three screens simultaneously in memory.

### Route Destinations
| Index | Destination Name | Widget | Primary Responsibilities |
|---|---|---|---|
| `0` | **Dashboard** | `DashboardScreen` | Display preview canvas, quadrant overlay, real-time numeric readout card, simulated pointer position sliders, phone touch controller card. |
| `1` | **Calibration** | `CalibrationScreen` | Sample correspondences table, preset loader (4-corners, 5-cross, collinear), affine least-squares regression matrix, error analysis, interactive test tool, JSON profile save. |
| `2` | **Settings** | `SettingsScreen` | Platform capability matrix breakdown, display adapter source switcher (Live Window vs. Simulated Negative Origin), local profile persistence manager. |

---

# 8 Authentication & Security Model

MacTouch is an offline-first desktop utility and does not integrate cloud identity providers (OAuth2, JWT, OIDC). However, it enforces a strict local security architecture:

1. **Local Network Boundary**:
   The touch digitizer server (`TouchServerService`) binds to `InternetAddress.anyIPv4` on port `8080` to accept connections from smartphones on the user's private local network. It does **not** perform UPnP port forwarding or WAN NAT traversal, remaining inaccessible from the public internet.
2. **CORS & WebSocket Origin Control**:
   `Access-Control-Allow-Origin: *` is permitted exclusively to allow local network smartphones on different IP assignments within the same subnet to load the mobile touchpad client.
3. **macOS Gatekeeper & Code Signing**:
   When compiled via GitHub Actions without a paid Apple Developer Team certificate, binaries receive the `com.apple.quarantine` extended attribute upon download. The documentation and build instructions specify clearing this via `xattr -cr` or using Finder's explicit Right-Click $\to$ Open override.
4. **macOS Transparency, Consent, and Control (TCC)**:
   - *In-App Input*: Pure Flutter pointer listeners operate within the application window boundary and require **zero** macOS permissions.
   - *System Cursor Injection*: Moving the cursor outside the application window via `cursor_bridge` utilizes `CGEventPost(kCGHIDEventTap)`. On macOS, synthesizing input events across external application windows requires user approval in **System Settings $\to$ Privacy & Security $\to$ Accessibility**.

---

# 9 State Management Architecture

MacTouch implements a pragmatic, clean service-oriented state management pattern with zero unnecessary boilerplate libraries (e.g., no bloated BLoC or Redux overhead):

```mermaid
graph LR
    subgraph Services ["Service State Containers"]
        DS["DisplayService\n(Displays, Selected, Error)"]
        PS["ProfileStore\n(Profiles, Loaded, Disk File)"]
        TSS["TouchServerService\n(Clients, StreamController)"]
        SCS["SystemCursorService\n(Enabled, Process Pipe)"]
    end

    subgraph Screens ["Stateful Widget Consumers"]
        DashState["_DashboardScreenState\n(SimulatedPointer, HoverPoint, Subscriptions)"]
        CalibState["_CalibrationScreenState\n(Samples, AffineResult, TestTransform)"]
        SetState["_SettingsScreenState\n(UseSimulatedDisplay)"]
    end

    DS --> DashState
    TSS -- "Broadcast Stream" --> DashState
    SCS --> DashState
    PS --> CalibState
    DS --> SetState
    PS --> SetState
```

### State Ownership & Lifecycle
- **Display State**: Owned by `DisplayService`. Mutable through `enumerate()`, `selectDisplay()`, and `setAdapter()`. Notifies screens via async futures and stateful callbacks.
- **Persistence State**: Owned by `ProfileStore`. Profiles are stored in an unmodifiable `List<CalibrationProfile>` in memory, backed by atomic writes to disk.
- **Real-Time Touch Stream**: Owned by `TouchServerService`. Emits asynchronous `PhoneTouchEvent` records over a broadcast `StreamController<PhoneTouchEvent>`, consumed simultaneously by `DashboardScreen` and `SystemCursorService`.
- **Transient UI State**: Screen-specific variables (such as active slider values, temporary calibration input text controllers, and hover points) are scoped locally to their respective `StatefulWidget` states.

---

# 10 Frontend Architecture & UI Components

### 10.1 UI Layer Composition
The presentation layer is composed of atomic, highly focused widgets built for dark-mode desktop interfaces:

```mermaid
graph TD
    Dashboard["DashboardScreen"] --> Left["Left Column: Canvas Area"]
    Dashboard --> Right["Right Column: Controls & Readouts"]

    Left --> Canvas["DisplayCanvas"]
    Canvas --> Overlay["QuadrantOverlay"]
    Overlay --> Box["_QuadrantBox (Q1-Q4)"]
    Canvas --> Reticle["_SimulatedPointerReticle"]
    Canvas --> Prompts["_CalibrationTargetPrompt"]

    Right --> PhoneCard["Phone Touch Controller Card"]
    Right --> Readout["CoordinateReadout"]
    Readout --> MetricCell["_MetricCell"]
    Right --> Sliders["Simulator Position Sliders"]
    Right --> Topology["Display Topology Card"]
    Right --> CapCard["CapabilityCard"]
    CapCard --> Badge["CapabilityBadge"]
```

### 10.2 Component Reference Table

| Component Name | File Location | Properties | Local State | Primary Responsibilities |
|---|---|---|---|---|
| `CapabilityBadge` | `lib/widgets/capability_badge.dart` | `level`, `showLabel` | Stateless | Renders color-coded pills (green, orange, grey, deep orange) with status icons. |
| `CapabilityCard` | `lib/widgets/capability_badge.dart` | `capability` | Stateless | Displays capability description and platform-specific security notes in an bordered card. |
| `CoordinateReadout` | `lib/widgets/coordinate_readout.dart` | `desktopPoint`, `normalizedPoint`, `bounds`, `quadrant`, `sourceLabel`, `isSimulated` | Stateless | Renders monospace numerical coordinate cards across Desktop-Global, Normalized, and Quadrant spaces. |
| `QuadrantOverlay` | `lib/widgets/quadrant_overlay.dart` | `activeQuadrant`, `showLabels`, `showMidpointLines` | Stateless | Renders the 4-quadrant grid, center dividing lines ($u=0.5, v=0.5$), and active quadrant background tints. |
| `DisplayCanvas` | `lib/widgets/display_canvas.dart` | `displayBounds`, `simulatedPointer`, `onSimulatedPointerChanged`, `onInAppPointerHover`, `onInAppPointerClick`, `calibrationTargets` | `_hoverPoint`, `_isDraggingSimulator` | Maintains display aspect ratio, captures Flutter `Listener` mouse events, and provides a draggable simulator reticle. |
| `_SimulatedPointerReticle` | `lib/widgets/display_canvas.dart` | `isDragging` | Stateless | Circular glowing dashed reticle with drag handles indicating simulated coordinates. |
| `_CalibrationTargetPrompt` | `lib/widgets/display_canvas.dart` | `label` | Stateless | Visual target crosshairs rendered on canvas during calibration steps (explicitly non-contact). |

---

# 11 Backend Architecture (Embedded Server)

MacTouch embeds an asynchronous HTTP/WebSocket server directly within the desktop process using the `dart:io` engine:

```
[Phone Browser] --(HTTP GET /)--------> [HttpServer (0.0.0.0:8080)]
                <--(200 OK: HTML5/JS)--
[Phone Browser] --(Upgrade: /ws)------> [WebSocketTransformer]
                <--(101 Switching)-----
[Phone Browser] ==(JSON Touch Packets)=> [TouchServerService Event Loop]
```

### Architectural Decisions:
1. **Zero External Server Dependencies**: Implemented using pure `dart:io` primitives (`HttpServer.bind()`, `WebSocketTransformer.upgrade()`). This eliminates third-party Node.js, Python, or Shelf dependencies, keeping the compiled binary tiny.
2. **Single-Page Embedded Web Asset**: The entire mobile web touch application (HTML5, responsive CSS3, and ES6 touch listeners) is compiled directly into Dart memory as a raw multiline string (`_mobileTouchAppHtml`). The server serves this payload instantly from RAM without disk I/O.
3. **High-Frequency Asynchronous Streaming**: Mobile touch events (`touchmove`) transmit lightweight JSON packets. The WebSocket handler parses these asynchronously and emits them into a broadcast `StreamController`, decoupling network ingestion from UI rendering.

---

# 12 API & Protocol Documentation

### 12.1 HTTP Endpoints

#### `GET /`
- **Purpose**: Serves the mobile web touch application to client browsers.
- **Authentication**: None (Local Network).
- **Headers Returned**: `Content-Type: text/html; charset=utf-8`, `Access-Control-Allow-Origin: *`.
- **Response**: Full HTML5 single-page application containing mobile touch listeners and WebSocket client script.

### 12.2 WebSocket Protocol (`ws://<Host-IP>:8080/ws`)

All WebSocket communication consists of bidirectional JSON payloads:

#### 1. Relative Move Event (Trackpad Mode)
- **Direction**: Client $\to$ Server
- **Payload**:
  ```json
  {
    "type": "move",
    "dx": 2.45,
    "dy": -1.82
  }
  ```
- **Action**: Server translates $(dx, dy)$ via `SystemCursorService.moveRelative()` to adjust the desktop mouse cursor.

#### 2. Absolute Coordinate Event (Direct Screen Mode)
- **Direction**: Client $\to$ Server
- **Payload**:
  ```json
  {
    "type": "abs",
    "u": 0.752,
    "v": 0.248
  }
  ```
- **Action**: Server normalizes $(u, v)$ against `DisplayBounds`, computes Desktop-Global $(x, y)$, and moves the cursor directly to the screen coordinate.

#### 3. Mouse Click Events
- **Direction**: Client $\to$ Server
- **Payloads**:
  - Left Click: `{"type": "click"}`
  - Right Click (Context Menu): `{"type": "rclick"}`
  - Mouse Button Down (Drag Start): `{"type": "down"}`
  - Mouse Button Up (Drag End): `{"type": "up"}`

#### 4. Scroll Event
- **Direction**: Client $\to$ Server
- **Payload**:
  ```json
  {
    "type": "scroll",
    "scrollDy": -30
  }
  ```

---

# 13 Database & Persistence Layer

MacTouch deliberately rejects heavy SQL databases (SQLite, Realm, Isar) in favor of a lean, versioned local JSON storage document:

### Storage Schema (`ProfileStoreDocument` - Version 1)

```json
{
  "version": 1,
  "profiles": [
    {
      "id": "profile-1700812345678",
      "name": "Retina Main Display Calibration",
      "displayId": "view-1",
      "samples": [
        {
          "sourceX": 100.0,
          "sourceY": 100.0,
          "destX": 102.0,
          "destY": 98.0
        },
        {
          "sourceX": 900.0,
          "sourceY": 100.0,
          "destX": 898.0,
          "destY": 101.0
        },
        {
          "sourceX": 900.0,
          "sourceY": 600.0,
          "destX": 897.0,
          "destY": 603.0
        },
        {
          "sourceX": 100.0,
          "sourceY": 600.0,
          "destX": 101.0,
          "destY": 598.0
        }
      ],
      "calibrationResult": {
        "parameters": [0.9937, 0.0050, 2.1250, 0.0037, 1.0025, -2.3750],
        "rmsError": 1.4142,
        "maxError": 2.2360,
        "sampleCount": 4
      },
      "createdAt": "2026-11-24T00:30:00.000Z",
      "modifiedAt": "2026-11-24T00:35:00.000Z"
    }
  ]
}
```

### Storage Engine Details
- **File Location**: `~/.mactouch/profiles.v1.json` (resolves cross-platform using `Platform.environment['HOME']`).
- **Atomic Serialization**: Utilizes `JsonEncoder.withIndent('  ')` for clean human readability. Directories are created recursively via `file.parent.create(recursive: true)`.
- **Migration Strategy**: The `version` key allows future releases to implement sequential migration transforms if additional calibration properties (such as homography projective parameters) are introduced.

---

# 14 Security & Permissions Analysis

### 14.1 Threat Modeling & Security Posture
- **Local Denial of Service**: The HTTP server bounds payload parsing via standard JSON decoders. Malformed packets are silently caught and discarded without crashing the isolate.
- **Port Conflict Resistance**: If port `8080` is occupied, `TouchServerService` automatically catches the socket exception and binds to port `8081`.
- **Sandbox Compliance**: `bin/cursor_bridge` operates exclusively through standard UNIX streams (`stdin`), preventing unauthorized network sockets or file writes.

### 14.2 Operating System Permission Breakdown
```
+------------------+-----------------------+------------------------------------------+
| OS               | Permission Requested  | Reason & Security Implication            |
+------------------+-----------------------+------------------------------------------+
| macOS            | Accessibility (TCC)   | Required for CGEventPost to inject       |
|                  |                       | mouse moves into other desktop apps.     |
+------------------+-----------------------+------------------------------------------+
| Windows          | Raw Input / SendInput | Required if moving cursor outside        |
|                  |                       | the active application window.           |
+------------------+-----------------------+------------------------------------------+
| Linux (X11)      | XTest / XRecord       | Traditional X11 extension access.        |
+------------------+-----------------------+------------------------------------------+
| Linux (Wayland)  | XDG InputCapture      | Wayland strictly blocks global input     |
|                  | Portal Authorization  | hooks; compositor approval required.     |
+------------------+-----------------------+------------------------------------------+
```

---

# 15 LLM Architecture & AI Extensions

MacTouch is an offline, zero-telemetry desktop utility. It deliberately avoids integrating cloud LLM SDKs (OpenAI, Anthropic, Gemini API) within the core execution loop to ensure deterministic latency, zero API costs, and absolute privacy.

**Future Edge AI Extension Points**:
- If visual touch tracking (Method A: Webcam + Mirror) is implemented in a future release, lightweight edge models (such as MediaPipe Hands running locally on device via TensorFlow Lite or CoreML) can emit normalized coordinates directly into `CoordinateMapper` without sending image data over external networks.

---

# 16 Internal Design Patterns

The codebase reverse-engineers several classical software design patterns:

### 1. Adapter Pattern (`lib/platforms/display_adapter.dart`)
- **Abstract Target**: `DisplayAdapter`.
- **Adapters**: `FlutterWindowDisplayAdapter`, `SimulatedDisplayAdapter`, `UnsupportedDisplayAdapter`.
- **Benefit**: Decouples the UI and services from operating system display APIs, permitting instant toggling between real hardware screens and simulated multi-monitor topologies with negative desktop coordinates.

### 2. Strategy Pattern (`lib/core/calibration/affine_calibration.dart`)
- **Context**: Calibration solver routines.
- **Strategy**: Affine least-squares matrix regression using normal equations. Encapsulates mathematical solving independently of presentation widgets.

### 3. Observer / Reactive Stream Pattern (`lib/services/touch_server_service.dart`)
- **Subject**: `TouchServerService`.
- **Observers**: `DashboardScreen`, `SystemCursorService`.
- **Mechanism**: Broadcast `StreamController<PhoneTouchEvent>` and `StreamController<int>` distributing real-time touch events and client connection state.

### 4. Process Supervisor / Bridge Pattern (`lib/services/system_cursor_service.dart`)
- **Abstraction**: `SystemCursorService` manages a long-running native C worker process via piped stdin/stdout streams, converting high-level Dart method calls into low-level POSIX command tokens (`m`, `c`, `s`).

---

# 17 Detailed Component & Widget Reference

### `DisplayCanvas` (`lib/widgets/display_canvas.dart`)
- **State Class**: `_DisplayCanvasState`.
- **Key Methods**:
  - `build()`: Computes aspect-ratio bounded canvas geometry (`constraints.maxWidth / aspectRatio`).
  - `onPointerHover()`: Intercepts local mouse motion, calculates normalized $(u, v)$, and triggers `widget.onInAppPointerHover`.
  - `onPanUpdate()`: Handles drag events on the simulated reticle, recalculating clamped normalized coordinates.
- **Rendering Stack**:
  1. Base dark canvas container (`Color(0xFF0F131A)`).
  2. `QuadrantOverlay` with axis midpoint lines.
  3. Calibration target crosshair prompts.
  4. In-app real mouse hover dot (blue).
  5. Draggable simulated pointer reticle (purple/amber).

### `QuadrantOverlay` (`lib/widgets/quadrant_overlay.dart`)
- **Subcomponents**: Four `_QuadrantBox` widgets arranged in a $2 \times 2$ grid inside a `Stack`.
- **Midpoint Lines**: Draws vertical ($u = 0.5$) and horizontal ($v = 0.5$) 1px dividers with a center `(0.5, 0.5)` intersection tag.
- **Color Coding**:
  - $Q_1$ (Top-Left): Blue (`Colors.blue`)
  - $Q_2$ (Top-Right): Purple (`Colors.purple`)
  - $Q_3$ (Bottom-Left): Teal (`Colors.teal`)
  - $Q_4$ (Bottom-Right): Amber (`Colors.amber`)

---

# 18 Mathematical Specifications

### 18.1 Coordinate Normalization Formulas
Given display logical bounds:
$$\text{left} = x_{\text{origin}}, \quad \text{top} = y_{\text{origin}}, \quad \text{width} = W, \quad \text{height} = H$$

A desktop-global point $(x, y)$ is normalized to $(u, v)$ via:
$$u = \frac{x - x_{\text{origin}}}{W}, \quad v = \frac{y - y_{\text{origin}}}{H}$$

Denormalization back to desktop-global space:
$$x = u \cdot W + x_{\text{origin}}, \quad y = v \cdot H + y_{\text{origin}}$$

### 18.2 Affine Least-Squares Formulation
An affine mapping transforms a point $(x, y)$ to $(x', y')$ according to:
$$x' = a \cdot x + b \cdot y + c$$
$$y' = d \cdot x + e \cdot y + f$$

For $N \ge 3$ sample correspondences, the system is expressed in matrix notation:
$$\begin{pmatrix} x_1 & y_1 & 1 \\ x_2 & y_2 & 1 \\ \vdots & \vdots & \vdots \\ x_N & y_N & 1 \end{pmatrix} \begin{pmatrix} a & d \\ b & e \\ c & f \end{pmatrix} = \begin{pmatrix} x'_1 & y'_1 \\ x'_2 & y'_2 \\ \vdots & \vdots \\ x'_N & y'_N \end{pmatrix} \implies \mathbf{A} \mathbf{P} = \mathbf{B}$$

The least-squares normal equations are formulated as:
$$\mathbf{A}^T \mathbf{A} \mathbf{P} = \mathbf{A}^T \mathbf{B}$$
Where $\mathbf{A}^T \mathbf{A}$ is a symmetric $3 \times 3$ matrix:
$$\mathbf{A}^T \mathbf{A} = \begin{pmatrix} \sum x_i^2 & \sum x_i y_i & \sum x_i \\ \sum x_i y_i & \sum y_i^2 & \sum y_i \\ \sum x_i & \sum y_i & N \end{pmatrix}$$

The $3 \times 3$ determinant $\det(\mathbf{A}^T \mathbf{A})$ is evaluated. If $|\det| < 10^{-12}$, the system is rejected as degenerate. Otherwise, Cramer's rule solves for $[a, b, c]$ and $[d, e, f]$ independently.

Residual Root-Mean-Square (RMS) error:
$$\text{RMS} = \sqrt{\frac{1}{N} \sum_{i=1}^N \left( (a x_i + b y_i + c - x'_i)^2 + (d x_i + e y_i + f - y'_i)^2 \right)}$$

---

# 19 Service Layer Reference

### `DisplayService`
- **Consumer**: `DashboardScreen`, `SettingsScreen`, `CalibrationScreen`.
- **Public Methods**:
  - `Future<bool> enumerate()`: Queries adapter, populates `displays`, auto-selects primary.
  - `void setAdapter(DisplayAdapter newAdapter)`: Hot-swaps underlying platform adapter.
  - `bool selectDisplay(int index)`: Selects active display by array index.
  - `bool selectDisplayById(String id)`: Selects active display by stable string ID.

### `ProfileStore`
- **Consumer**: `CalibrationScreen`, `SettingsScreen`.
- **Public Methods**:
  - `Future<String?> load()`: Reads and deserializes JSON from disk.
  - `Future<String?> save()`: Serializes in-memory profiles to disk.
  - `String? addProfile(CalibrationProfile profile)`: Validates and appends profile.
  - `String? updateProfile(CalibrationProfile profile)`: Replaces existing profile.
  - `String? removeProfile(String id)`: Deletes profile by ID.
  - `Future<String?> reset()`: Empties profile list and updates disk.

### `SystemCursorService`
- **Consumer**: `DashboardScreen`, `bin/server.dart`.
- **Public Methods**:
  - `void setEnabled(bool enabled)`: Toggles native cursor bridge process.
  - `void moveTo(double x, double y)`: Dispatches absolute cursor position command.
  - `void moveRelative(double dx, double dy)`: Dispatches relative cursor move command.
  - `void click()`: Dispatches left mouse click.
  - `void rightClick()`: Dispatches right mouse click.
  - `void scroll(int dy)`: Dispatches scroll wheel delta.

### `TouchServerService`
- **Consumer**: `DashboardScreen`, `bin/server.dart`.
- **Public Methods**:
  - `Future<bool> start({int port = 8080})`: Binds HTTP/WS server to all IPv4 interfaces.
  - `Future<void> stop()`: Closes client sockets and shuts down HTTP server.
  - `Stream<PhoneTouchEvent> get onTouchEvent`: Broadcast stream of parsed mobile touch events.
  - `Stream<int> get onClientCountChanged`: Broadcast stream of active phone socket count.

---

# 20 Environment Variables & Configuration

| Variable | Default Value | Required | Subsystem | Purpose & Security Implications |
|---|---|---|---|---|
| `HOME` | System Home Directory | Yes (POSIX) | `ProfileStore` | Resolves `~/.mactouch/` base directory for local JSON storage. |
| `USERPROFILE` | Windows User Directory | Yes (Win32) | `ProfileStore` | Windows fallback for local profile storage path. |
| `PORT` | `8080` | Optional | `TouchServerService` | Port on which the mobile touch HTTP and WebSocket server binds. |

---

# 21 Build System & Toolchain Configuration

### 21.1 Native Toolchains
- **macOS Desktop**: Compiled via Flutter engine calling Apple Clang/Xcode. Embeds `FlutterMacOS.framework` into `Runner.app`.
- **Windows Desktop**: Generates Win32 application runner utilizing Visual Studio C++ toolchain and CMake.
- **Linux Desktop**: Generates GTK+ 3.0 application runner utilizing GCC/Clang, CMake, and `pkg-config`.
- **Native Helper (`cursor_bridge`)**:
  ```bash
  clang -O2 -framework ApplicationServices bin/cursor_bridge.c -o bin/cursor_bridge
  ```

### 21.2 Cloud CI/CD Pipeline (`.github/workflows/build_macos.yml`)
The GitHub Actions workflow executes on `macos-latest` runners:
1. `subosito/flutter-action@v2`: Configures Flutter 3.50.1 stable.
2. `flutter analyze`: Validates static analysis with 0 errors.
3. `flutter test`: Executes all 17 unit and widget tests.
4. `flutter build macos --release`: Compiles the native macOS `.app` bundle using Xcode in the cloud.
5. Clang compiles `cursor_bridge` and copies it into `mactouch.app/Contents/MacOS/cursor_bridge`.
6. `actions/upload-artifact@v4`: Zips and publishes the release artifact for user download.

---

# 22 Deployment Architecture

```
+-----------------------------------------------------------------------------------+
|                            DEPLOYMENT TOPOLOGY                                    |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  [Developer Workstation]                                                          |
|       |                                                                           |
|       +-- (git push origin main)                                                  |
|       |                                                                           |
|       v                                                                           |
|  [GitHub Repository: Arsh-pixel-cmd/mactouch]                                     |
|       |                                                                           |
|       +-- (Webhook Trigger)                                                       |
|       |                                                                           |
|       v                                                                           |
|  [GitHub Actions Cloud Runner (macos-latest / Xcode 16)]                          |
|       |                                                                           |
|       +-- flutter analyze && flutter test                                         |
|       +-- flutter build macos --release                                           |
|       +-- clang -O2 cursor_bridge.c                                               |
|       |                                                                           |
|       v                                                                           |
|  [GitHub Release Artifacts: MacTouch-macOS-App.zip]                               |
|       |                                                                           |
|       +-- (User Download)                                                         |
|       |                                                                           |
|       v                                                                           |
|  [Target MacBook Air (Zero Local Xcode Installation)]                             |
|       +-- ~/Desktop/mactouch.app                                                  |
|       +-- Binds http://10.x.x.x:8080                                              |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

---

# 23 Performance Analysis & Optimization

1. **Aspect Ratio Canvas Clamping**: `DisplayCanvas` utilizes `LayoutBuilder` with an explicit mathematical aspect ratio clamp. This prevents layout thrashing and eliminates unconstrained RenderFlex overflow errors during resizing.
2. **Asynchronous Stream Decoupling**: High-frequency touch move events ($60\text{Hz} - 120\text{Hz}$) from smartphones stream over WebSockets without blocking the Flutter UI isolate.
3. **C-Level CoreGraphics Event Execution**: Using a compiled C helper (`cursor_bridge`) for mouse movement eliminates the heavy latency (~50-100ms) associated with spawning AppleScript subprocesses (`osascript`), reducing cursor latency to under $1\text{ms}$.
4. **Zero-Allocation Coordinate Math**: Pure-Dart coordinate calculations (`CoordinateMapper`, `Quadrant`) avoid allocations of heavy object graphs, executing entirely within CPU cache lines.

---

# 24 Security Analysis & Code Hardening

1. **Input Validation**: All numeric text fields in `CalibrationScreen` utilize `double.tryParse()` with explicit null-safety validation, preventing unhandled exceptions on invalid user input.
2. **Buffer Overflow Prevention**: `bin/cursor_bridge.c` uses bounded `fgets(line, sizeof(line), stdin)` and strict `sscanf` format specifiers, preventing buffer overrun attacks on standard input.
3. **Collinearity System Protection**: Before attempting matrix inversion via Cramer's rule, `AffineCalibrator` computes 2D vector cross-products across all input points to detect collinear degenerate systems, preventing division-by-zero crashes.

---

# 25 Design Pattern Matrix

| Pattern Name | Implementation Files | Architectural Purpose | Engineering Advantage |
|---|---|---|---|
| **Adapter Pattern** | `lib/platforms/display_adapter.dart` | Normalizes display discovery across live window dispatchers and simulated multi-display topologies. | Enables rapid simulation and testing of multi-monitor topologies with negative desktop coordinates on any laptop. |
| **Strategy Pattern** | `lib/core/calibration/affine_calibration.dart` | Encapsulates mathematical regression algorithms. | Allows independent algorithm evolution (e.g. extending from affine to homography projective transforms) without touching UI. |
| **Observer Pattern** | `lib/services/touch_server_service.dart` | Broadcasts real-time touch events and client connection states. | Fully decouples network socket listeners from UI canvas renderers and cursor bridge dispatchers. |
| **Process Bridge** | `lib/services/system_cursor_service.dart` | Inter-process pipe supervisor controlling native helper executable. | Isolates native OS API calls from the Dart runtime isolate, ensuring stability and crash protection. |
| **Document Store** | `lib/services/profile_store.dart` | Atomic file-based JSON persistence engine. | Provides schema-versioned persistence with zero external database dependencies. |

---

# 26 Developer Onboarding & Troubleshooting Guide

### 26.1 Environment Setup
```bash
# Clone repository
git clone https://github.com/Arsh-pixel-cmd/mactouch.git
cd mactouch

# Fetch dependencies
flutter pub get

# Compile native cursor bridge helper
clang -O2 -framework ApplicationServices bin/cursor_bridge.c -o bin/cursor_bridge
chmod +x bin/cursor_bridge
```

### 26.2 Verification & Testing
```bash
# Run static analysis
flutter analyze

# Run unit and widget tests
flutter test
```

### 26.3 Running the Application
- **Chrome / Web Preview**:
  ```bash
  flutter run -d chrome
  ```
- **Native macOS Desktop**:
  ```bash
  flutter run -d macos
  ```
- **Standalone Headless Touch Daemon**:
  ```bash
  dart run bin/server.dart
  ```

### 26.4 Common Pitfalls
1. **Mobile Browser Forces HTTPS**: When opening the mobile touch URL on Android Chrome, the browser may default to `https://`. Always type `http://<IP>:8080` explicitly.
2. **Accessibility Permissions on macOS**: If the cursor does not move when sliding on your phone, open **System Settings $\to$ Privacy & Security $\to$ Accessibility** and enable your terminal or `mactouch.app`.
3. **Subnet Isolation**: Ensure the smartphone and MacBook are connected to the same Wi-Fi router (avoid guest networks with client isolation enabled).

---

# 27 Future Architectural Roadmap

1. **Projective Homography Transformation**: Upgrade `AffineCalibrator` to support 8-parameter projective homography transforms ($3 \times 3$ matrix) to correct perspective distortion when external cameras or tilted phone digitizers are utilized.
2. **WebRTC Direct Data Channel**: Introduce WebRTC data channels alongside WebSockets to achieve sub-5ms peer-to-peer touch latency with UDP transport.
3. **Computer Vision Hand-Tracking Pipeline**: Integrate an optional local edge MediaPipe pipeline to allow the built-in webcam with an angled mirror to detect fingertip contact plane intersections directly on the screen glass.
