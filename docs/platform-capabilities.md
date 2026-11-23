# MacTouch — Platform Capabilities & Permissions Truth Table

Flutter provides a shared cross-platform UI framework for desktop targets (macOS, Windows, Linux). However, low-level device access, display topology, global input monitoring, and event synthesis are **not** inherently portable.

This document records the exact capability status and platform permission requirements across operating systems.

---

## Capabilities Truth Table

| Capability | Scope in v1 | macOS Status & Requirements | Windows Status & Requirements | Linux (X11) Status & Requirements | Linux (Wayland) Status & Requirements |
|---|---|---|---|---|---|
| **In-App Pointer Events** | P1 | **Supported** via normal Flutter `Listener` / `MouseRegion` while the app window is active. | **Supported** via normal Flutter `Listener` / `MouseRegion`. | **Supported** via normal Flutter `Listener` / `MouseRegion`. | **Supported** via normal Flutter `Listener` / `MouseRegion`. |
| **Window/View Display Bounds** | P0 | **Supported** via `FlutterWindowDisplayAdapter` (reports active window size & scale factor). | **Supported** via Flutter view dispatcher. | **Supported** via Flutter view dispatcher. | **Supported** via Flutter view dispatcher. |
| **OS-Wide Multi-Display Topology** | P1 | **Partial / Estimated** via `SimulatedDisplayAdapter`. Native requires `NSScreen.screens` adapter. | **Partial / Estimated**. Native requires `EnumDisplayMonitors` win32 adapter. | **Partial / Estimated**. Native requires `XRandR` native adapter. | **Partial / Estimated**. Native requires `wl_output` / compositor protocol. |
| **Simulated Pointer & Coordinate Readout** | P0 | **Supported**. Pure-Dart deterministic simulation. | **Supported**. | **Supported**. | **Supported**. |
| **Affine Calibration Math & Profiles** | P0 | **Supported**. Pure-Dart least-squares affine solver + local JSON store. | **Supported**. | **Supported**. | **Supported**. |
| **Global Input Monitoring** | P2 (Non-goal in v1) | **Unsupported**. Requires user grant in `System Settings > Privacy & Security > Input Monitoring` or `Accessibility`. | **Unsupported**. Requires Windows Raw Input API hook (`RegisterRawInputDevices`). | **Unsupported**. Requires X11 `XRecord` or `XGrabPointer` hooks. | **Blocked / Restricted**. Wayland compositors prohibit global snooping. Requires `xdg-desktop-portal` InputCapture with explicit user confirmation. |
| **Touchscreen Hardware Detection** | P2 (Non-goal in v1) | **Unsupported**. Stock MacBook hardware lacks touch sensors entirely. | **Unsupported**. Requires Win32 `GetSystemMetrics(SM_DIGITIZER)`. | **Unsupported**. Requires `libinput` / `udev` queries. | **Unsupported**. Requires `libinput` compositor touch protocol. |
| **System Cursor Injection / Click Synthesis** | Non-goal | **Unsupported**. Explicit non-goal to prevent security and permission escalation. | **Unsupported**. | **Unsupported**. | **Unsupported**. |

---

## Operating System Specific Guidance

### 1. macOS
- **Hardware Truth**: Conventional MacBooks have no touchscreen hardware. Trackpad gesture events delivered to the app are trackpad events, not screen touches.
- **Permissions**:
  - Global event taps (`CGEventTapCreate`) require **Accessibility** permission.
  - Keyboard/mouse snooping requires **Input Monitoring** permission (`IOHIDManager`).
  - MacTouch v1 deliberately avoids requesting these permissions by restricting pointer tracking to the active Flutter application window.

### 2. Windows
- **Raw Input API**: `RegisterRawInputDevices` allows applications to receive raw input from human interface devices (HID).
- **Multi-Monitor Coordinate Space**: Windows uses a virtual screen coordinate space where secondary monitors positioned to the left or top receive negative coordinate bounds.

### 3. Linux: X11 vs. Wayland
- **X11**: Applications can historically register global hotkeys or listen to global X events using `XRecordExtension` or `XGrabPointer`.
- **Wayland**: Compositor-enforced security model prevents clients from inspecting or capturing pointer/touch coordinates outside their own surfaces.
- **XDG InputCapture Portal**: Any future global capture on Wayland must go through `org.freedesktop.portal.InputCapture`, requiring explicit compositor support and user authorization prompts. MacTouch does not assume global access is available.
