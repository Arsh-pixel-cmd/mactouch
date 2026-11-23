import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mactouch/app.dart';
import 'package:mactouch/models/capability_status.dart';
import 'package:mactouch/platforms/display_adapter.dart';
import 'package:mactouch/screens/dashboard/dashboard_screen.dart';
import 'package:mactouch/services/display_service.dart';
import 'package:mactouch/services/profile_store.dart';
import 'package:mactouch/widgets/capability_badge.dart';
import 'package:mactouch/widgets/coordinate_readout.dart';
import 'package:mactouch/widgets/display_canvas.dart';
import 'package:mactouch/widgets/quadrant_overlay.dart';

void main() {
  group('Widget Tests', () {
    testWidgets('Dashboard renders display canvas, quadrants, readout and simulator', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final displayAdapter = const SimulatedDisplayAdapter();
      final displayService = DisplayService(displayAdapter);
      await displayService.enumerate();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardScreen(displayService: displayService),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify canvas and quadrant overlay are present
      expect(find.byType(DisplayCanvas), findsOneWidget);
      expect(find.byType(QuadrantOverlay), findsOneWidget);
      expect(find.byType(CoordinateReadout), findsOneWidget);

      // Verify quadrant labels exist in overlay
      expect(
        find.descendant(of: find.byType(QuadrantOverlay), matching: find.text('Q1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(QuadrantOverlay), matching: find.text('Q2')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(QuadrantOverlay), matching: find.text('Q3')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(QuadrantOverlay), matching: find.text('Q4')),
        findsOneWidget,
      );

      // Verify non-contact honest disclaimer notice
      expect(find.textContaining('Conventional MacBook screens lack touch sensors'), findsOneWidget);
    });

    testWidgets('CapabilityBadge displays correct honest support level', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CapabilityBadge(level: CapabilityLevel.supported),
                CapabilityBadge(level: CapabilityLevel.unsupported),
                CapabilityBadge(level: CapabilityLevel.permissionRequired),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Supported'), findsOneWidget);
      expect(find.text('Unsupported in v1'), findsOneWidget);
      expect(find.text('Permission Required'), findsOneWidget);
    });

    testWidgets('MacTouch navigation rail switches between screens', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final displayAdapter = const SimulatedDisplayAdapter();
      final displayService = DisplayService(displayAdapter);
      await displayService.enumerate();
      final profileStore = ProfileStore('/dev/null');

      await tester.pumpWidget(
        MacTouchApp(
          displayService: displayService,
          profileStore: profileStore,
        ),
      );
      await tester.pumpAndSettle();

      // Starts on Dashboard
      expect(find.text('Display Canvas'), findsOneWidget);

      // Switch to Calibration screen
      await tester.tap(find.text('Calibration'));
      await tester.pumpAndSettle();
      expect(find.text('Hardware Truth & Scope Disclaimer'), findsOneWidget);
      expect(find.text('Sample Correspondences'), findsOneWidget);

      // Switch to Settings screen
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Settings & Platform Capability Matrix'), findsOneWidget);
      expect(find.text('Display Discovery Source'), findsOneWidget);
    });
  });
}
