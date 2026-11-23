# MacTouch — Limitations and Non-Goals

MacTouch v1 is designed with strict product honesty. This document outlines architectural boundaries, non-goals, and technical limitations.

---

## Non-Goals & Honest Limitations

### 1. No Screen Contact Sensing on Standard MacBooks
- **Fact**: A standard MacBook display is not a touchscreen. Without physical touch sensor digitizers (e.g., an external capacitive or optical overlay, or an external graphics tablet), there is no physical contact signal to detect.
- **Rule**: The app never claims that tapping or pressing on a MacBook display can be detected.

### 2. On-Screen Calibration Targets Do Not Sense Touch
- **Fact**: Visual targets displayed on the canvas are prompts for a user or external test harness to provide known reference coordinates.
- **Rule**: The app does not market visual targets as "automatic calibration". Calibration in v1 computes an affine coordinate transform from manually entered or simulated sample pairs.

### 3. Quadrants Are Geometric Partitions, Not Gestures
- **Fact**: The 4 quadrants (Q1-Q4) are deterministic mathematical regions in normalized coordinate space $[0, 1] \times [0, 1]$.
- **Rule**: Entering a quadrant does not infer or fabricate gesture input.

### 4. No Cursor Synthesis or Click Injection
- **Fact**: Moving the operating system cursor or injecting mouse clicks requires OS-level permissions (e.g. macOS Accessibility, Windows `SendInput`, or uinput on Linux) and introduces security risks.
- **Rule**: MacTouch v1 operates exclusively with in-app pointer simulation and in-app event tracking. It does not synthesize OS-wide cursor movement.

### 5. In-App Pointer Events Only
- Pointer events are captured exclusively while the MacTouch application window is focused and active, using Flutter's native event dispatchers.
- No background keystroke monitoring or global pointer hooks are loaded.

### 6. Local-Only Persistence
- Profiles are saved to a versioned local JSON file (`~/.mactouch/profiles.v1.json`).
- No telemetry, analytics, cloud synchronization, or remote networking is performed.
