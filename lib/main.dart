import 'dart:io';
import 'package:flutter/material.dart';
import 'app.dart';
import 'platforms/display_adapter.dart';
import 'services/display_service.dart';
import 'services/profile_store.dart';
import 'services/touch_server_service.dart';
import 'services/system_cursor_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize display service (defaults to Live Flutter Window view)
  const displayAdapter = FlutterWindowDisplayAdapter();
  final displayService = DisplayService(displayAdapter);
  await displayService.enumerate();

  // Determine local profile storage path (per-user versioned JSON, no network)
  final homeDir = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';
  final profileDir = '$homeDir/.mactouch';
  final profilePath = '$profileDir/profiles.v1.json';

  final profileStore = ProfileStore(profilePath);
  await profileStore.load();

  // Initialize the Phone Touch Server (runs locally on port 8080)
  final touchServer = TouchServerService();
  await touchServer.start(port: 8080);

  // Initialize the native macOS cursor control bridge
  final cursorService = SystemCursorService();
  cursorService.setEnabled(true);

  runApp(MacTouchApp(
    displayService: displayService,
    profileStore: profileStore,
    touchServer: touchServer,
    cursorService: cursorService,
  ));
}
