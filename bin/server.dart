import 'dart:io';
import '../lib/services/system_cursor_service.dart';
import '../lib/services/touch_server_service.dart';

void main() async {
  print('====================================================');
  print('📱 MacTouch Phone Digitizer Server');
  print('====================================================');

  final touchServer = TouchServerService();
  final started = await touchServer.start(port: 8080);

  if (!started) {
    print('❌ Failed to bind to port 8080. Trying 8081...');
    await touchServer.start(port: 8081);
  }

  final cursorService = SystemCursorService();
  cursorService.setEnabled(true);

  print('✅ Server is RUNNING on your Mac!');
  print('');
  print('👉 OPEN THIS URL ON YOUR PHONE (iPhone Safari or Android Chrome):');
  print('   http://${touchServer.localIp}:${touchServer.port}');
  print('');
  print('⚠️ IMPORTANT: Make sure to type "http://" and NOT "https://"');
  print('   and ensure your phone is connected to the same Wi-Fi network.');
  print('====================================================');

  touchServer.onClientCountChanged.listen((count) {
    if (count > 0) {
      print('📱 Phone connected! Touch your phone screen to control your Mac.');
    } else {
      print('📱 Phone disconnected. Waiting for connection...');
    }
  });

  touchServer.onTouchEvent.listen((event) {
    if (event.type == 'move' && event.dx != null && event.dy != null) {
      cursorService.moveRelative(event.dx!, event.dy!);
    } else if (event.type == 'click') {
      print('👆 Left Click from phone');
      cursorService.click();
    } else if (event.type == 'rclick') {
      print('👆 Right Click from phone');
      cursorService.rightClick();
    } else if (event.type == 'down') {
      cursorService.mouseDown();
    } else if (event.type == 'up') {
      cursorService.mouseUp();
    } else if (event.type == 'scroll' && event.scrollDy != null) {
      cursorService.scroll(event.scrollDy!);
    }
  });

  // Keep process alive
  await ProcessSignal.sigint.watch().first;
  print('Shutting down server...');
  touchServer.dispose();
  cursorService.dispose();
}
