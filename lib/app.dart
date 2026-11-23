import 'package:flutter/material.dart';
import 'screens/calibration/calibration_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'services/display_service.dart';
import 'services/profile_store.dart';

/// The root application widget for MacTouch.
class MacTouchApp extends StatelessWidget {
  final DisplayService displayService;
  final ProfileStore profileStore;

  const MacTouchApp({
    super.key,
    required this.displayService,
    required this.profileStore,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MacTouch',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121418),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.purpleAccent,
          surface: Color(0xFF1E222B),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF16181D),
          elevation: 0,
        ),
      ),
      home: MacTouchShell(
        displayService: displayService,
        profileStore: profileStore,
      ),
    );
  }
}

/// Main desktop application shell with navigation rail and top status bar.
class MacTouchShell extends StatefulWidget {
  final DisplayService displayService;
  final ProfileStore profileStore;

  const MacTouchShell({
    super.key,
    required this.displayService,
    required this.profileStore,
  });

  @override
  State<MacTouchShell> createState() => _MacTouchShellState();
}

class _MacTouchShellState extends State<MacTouchShell> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(displayService: widget.displayService),
      CalibrationScreen(
        displayService: widget.displayService,
        profileStore: widget.profileStore,
      ),
      SettingsScreen(
        displayService: widget.displayService,
        profileStore: widget.profileStore,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withAlpha(40),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.touch_app, size: 20, color: Colors.blueAccent),
            ),
            const SizedBox(width: 10),
            const Text(
              'MacTouch',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'MVP v1.0',
                style: TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.teal.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.tealAccent.withAlpha(80)),
              ),
              child: const Text(
                'Honest Desktop Coordinate Utility',
                style: TextStyle(fontSize: 11, color: Colors.tealAccent),
              ),
            ),
          ],
        ),
      ),
      body: Row(
        children: [
          // Desktop Navigation Rail
          NavigationRail(
            backgroundColor: const Color(0xFF16181D),
            selectedIndex: _selectedTabIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedTabIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: const IconThemeData(color: Colors.blueAccent),
            unselectedIconTheme: const IconThemeData(color: Colors.white54),
            selectedLabelTextStyle: const TextStyle(
              color: Colors.blueAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelTextStyle: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune),
                label: Text('Calibration'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1, color: Colors.white10),

          // Active Screen
          Expanded(
            child: IndexedStack(
              index: _selectedTabIndex,
              children: screens,
            ),
          ),
        ],
      ),
    );
  }
}
