import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Event dispatched from a connected phone touch client.
class PhoneTouchEvent {
  final String type;
  final double? dx;
  final double? dy;
  final double? u;
  final double? v;
  final int? scrollDy;

  const PhoneTouchEvent({
    required this.type,
    this.dx,
    this.dy,
    this.u,
    this.v,
    this.scrollDy,
  });
}

/// Service that runs a local HTTP & WebSocket server inside MacTouch.
///
/// Serves an ultra-responsive web touchpad to any smartphone (iPhone or Android)
/// on the same Wi-Fi network, converting the phone into a real touchscreen controller.
class TouchServerService {
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  final _eventController = StreamController<PhoneTouchEvent>.broadcast();
  final _clientCountController = StreamController<int>.broadcast();

  String _localIp = '127.0.0.1';
  int _port = 8080;
  bool _isRunning = false;

  String get localIp => _localIp;
  int get port => _port;
  bool get isRunning => _isRunning;
  int get connectedClients => _clients.length;
  String get connectionUrl => 'http://$_localIp:$_port';

  Stream<PhoneTouchEvent> get onTouchEvent => _eventController.stream;
  Stream<int> get onClientCountChanged => _clientCountController.stream;

  /// Start the local touch server.
  Future<bool> start({int port = 8080}) async {
    if (_isRunning) return true;
    _port = port;

    try {
      _localIp = await _findLocalIp();

      // Bind to all network interfaces on Wi-Fi/LAN
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _isRunning = true;

      _server!.listen(_handleHttpRequest);
      return true;
    } catch (e) {
      // Try next port if port is busy
      try {
        _port = port + 1;
        _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
        _isRunning = true;
        _server!.listen(_handleHttpRequest);
        return true;
      } catch (_) {
        _isRunning = false;
        return false;
      }
    }
  }

  void _handleHttpRequest(HttpRequest request) async {
    // Enable CORS
    request.response.headers.add('Access-Control-Allow-Origin', '*');

    if (request.uri.path == '/ws') {
      // Upgrade to WebSocket
      try {
        final socket = await WebSocketTransformer.upgrade(request);
        _handleWebSocketClient(socket);
      } catch (_) {}
      return;
    }

    // Serve HTML5 mobile web touch app
    request.response.headers.contentType = ContentType.html;
    request.response.write(_mobileTouchAppHtml);
    await request.response.close();
  }

  void _handleWebSocketClient(WebSocket socket) {
    _clients.add(socket);
    _clientCountController.add(_clients.length);

    socket.listen(
      (data) {
        try {
          final json = jsonDecode(data.toString()) as Map<String, dynamic>;
          final type = json['type'] as String? ?? 'move';
          final event = PhoneTouchEvent(
            type: type,
            dx: (json['dx'] as num?)?.toDouble(),
            dy: (json['dy'] as num?)?.toDouble(),
            u: (json['u'] as num?)?.toDouble(),
            v: (json['v'] as num?)?.toDouble(),
            scrollDy: (json['scrollDy'] as num?)?.toInt(),
          );
          _eventController.add(event);
        } catch (_) {}
      },
      onDone: () {
        _clients.remove(socket);
        _clientCountController.add(_clients.length);
      },
      onError: (_) {
        _clients.remove(socket);
        _clientCountController.add(_clients.length);
      },
    );
  }

  static Future<String> _findLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      // Prefer Wi-Fi / en0 interface
      for (final iface in interfaces) {
        if (iface.name.startsWith('en') || iface.name.startsWith('wl')) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback) return addr.address;
          }
        }
      }

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  Future<void> stop() async {
    for (final client in _clients) {
      try {
        await client.close();
      } catch (_) {}
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
  }

  void dispose() {
    stop();
    _eventController.close();
    _clientCountController.close();
  }

  // Ultra-responsive, dark-mode mobile web application for phones
  static const String _mobileTouchAppHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <title>MacTouch Phone Controller</title>
  <style>
    * {
      box-sizing: border-box;
      -webkit-touch-callout: none;
      -webkit-user-select: none;
      user-select: none;
      touch-action: none;
      margin: 0;
      padding: 0;
    }
    body {
      background: #0B0E14;
      color: #E2E8F0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      overflow: hidden;
      height: 100vh;
      height: 100dvh;
      display: flex;
      flex-direction: column;
    }
    header {
      padding: 12px 16px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      background: #151922;
      border-bottom: 1px solid rgba(255, 255, 255, 0.08);
      z-index: 10;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 8px;
      font-weight: 700;
      font-size: 15px;
      color: #60A5FA;
    }
    .status-badge {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 12px;
      padding: 4px 10px;
      border-radius: 20px;
      background: rgba(34, 197, 94, 0.15);
      color: #4ADE80;
      border: 1px solid rgba(34, 197, 94, 0.3);
    }
    .status-dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: #4ADE80;
      box-shadow: 0 0 8px #4ADE80;
    }
    .status-badge.disconnected {
      background: rgba(239, 68, 68, 0.15);
      color: #F87171;
      border-color: rgba(239, 68, 68, 0.3);
    }
    .status-badge.disconnected .status-dot {
      background: #F87171;
      box-shadow: none;
    }
    .mode-bar {
      display: flex;
      padding: 8px 16px;
      gap: 8px;
      background: #11141D;
    }
    .mode-btn {
      flex: 1;
      padding: 8px 0;
      border-radius: 6px;
      border: 1px solid rgba(255, 255, 255, 0.1);
      background: rgba(255, 255, 255, 0.04);
      color: #94A3B8;
      font-size: 12px;
      font-weight: 600;
      text-align: center;
    }
    .mode-btn.active {
      background: #2563EB;
      color: #FFFFFF;
      border-color: #3B82F6;
    }
    #touchpad {
      flex: 1;
      margin: 12px;
      background: radial-gradient(circle at 50% 50%, #1A202C 0%, #0F131A 100%);
      border: 1.5px solid rgba(255, 255, 255, 0.12);
      border-radius: 16px;
      position: relative;
      overflow: hidden;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: inset 0 2px 8px rgba(0,0,0,0.5);
    }
    .touchpad-hint {
      color: rgba(255, 255, 255, 0.25);
      font-size: 13px;
      pointer-events: none;
      text-align: center;
      line-height: 1.5;
    }
    .reticle {
      position: absolute;
      width: 44px;
      height: 44px;
      border-radius: 50%;
      border: 2px solid #60A5FA;
      background: rgba(96, 165, 250, 0.2);
      transform: translate(-50%, -50%);
      pointer-events: none;
      display: none;
      box-shadow: 0 0 12px rgba(96, 165, 250, 0.5);
    }
    footer {
      padding: 12px 16px;
      display: flex;
      gap: 10px;
      background: #151922;
      border-top: 1px solid rgba(255, 255, 255, 0.08);
    }
    .action-btn {
      flex: 1;
      padding: 14px 0;
      border-radius: 8px;
      border: 1px solid rgba(255, 255, 255, 0.12);
      background: #1E2430;
      color: #E2E8F0;
      font-size: 13px;
      font-weight: 600;
      text-align: center;
      cursor: pointer;
    }
    .action-btn:active {
      background: #2563EB;
      color: #FFF;
      transform: scale(0.98);
    }
  </style>
</head>
<body>
  <header>
    <div class="brand">
      <span>📱 MacTouch</span>
    </div>
    <div id="status" class="status-badge disconnected">
      <div class="status-dot"></div>
      <span id="status-text">Connecting...</span>
    </div>
  </header>

  <div class="mode-bar">
    <button id="mode-trackpad" class="mode-btn active" onclick="setMode('trackpad')">Trackpad Mode</button>
    <button id="mode-direct" class="mode-btn" onclick="setMode('direct')">Direct Screen (1:1 Touch)</button>
  </div>

  <main id="touchpad">
    <div class="touchpad-hint" id="hint-text">
      Slide 1 finger to move cursor<br>
      Tap to Click • 2 fingers to Scroll
    </div>
    <div id="reticle" class="reticle"></div>
  </main>

  <footer>
    <button class="action-btn" onclick="send({type: 'click'})">Left Click</button>
    <button class="action-btn" onclick="send({type: 'rclick'})">Right Click</button>
    <button class="action-btn" onclick="sendScroll(-30)">Scroll Up</button>
    <button class="action-btn" onclick="sendScroll(30)">Scroll Down</button>
  </footer>

  <script>
    let mode = 'trackpad'; // 'trackpad' or 'direct'
    let ws = null;
    let lastX = 0, lastY = 0;
    let touchCount = 0;
    let touchStartTime = 0;
    let hasMoved = false;

    const pad = document.getElementById('touchpad');
    const reticle = document.getElementById('reticle');
    const statusBadge = document.getElementById('status');
    const statusText = document.getElementById('status-text');

    function connect() {
      const loc = window.location;
      const wsUrl = (loc.protocol === 'https:' ? 'wss://' : 'ws://') + loc.host + '/ws';
      ws = new WebSocket(wsUrl);

      ws.onopen = () => {
        statusBadge.className = 'status-badge';
        statusText.innerText = 'Connected to Mac';
      };

      ws.onclose = () => {
        statusBadge.className = 'status-badge disconnected';
        statusText.innerText = 'Disconnected';
        setTimeout(connect, 1500);
      };

      ws.onerror = () => ws.close();
    }

    connect();

    function send(data) {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify(data));
      }
    }

    function sendScroll(dy) {
      send({ type: 'scroll', scrollDy: dy });
    }

    function setMode(newMode) {
      mode = newMode;
      document.getElementById('mode-trackpad').className = 'mode-btn ' + (mode === 'trackpad' ? 'active' : '');
      document.getElementById('mode-direct').className = 'mode-btn ' + (mode === 'direct' ? 'active' : '');
      document.getElementById('hint-text').innerHTML = mode === 'trackpad'
        ? 'Slide 1 finger to move cursor<br>Tap to Click • 2 fingers to Scroll'
        : 'Phone screen maps 1:1 to MacBook Display<br>Touch anywhere to position cursor directly';
    }

    pad.addEventListener('touchstart', (e) => {
      e.preventDefault();
      touchCount = e.touches.length;
      touchStartTime = Date.now();
      hasMoved = false;

      const t = e.touches[0];
      const rect = pad.getBoundingClientRect();
      lastX = t.clientX;
      lastY = t.clientY;

      reticle.style.display = 'block';
      reticle.style.left = (t.clientX - rect.left) + 'px';
      reticle.style.top = (t.clientY - rect.top) + 'px';

      if (mode === 'direct') {
        const u = Math.max(0, Math.min(1, (t.clientX - rect.left) / rect.width));
        const v = Math.max(0, Math.min(1, (t.clientY - rect.top) / rect.height));
        send({ type: 'abs', u, v });
      }
    });

    pad.addEventListener('touchmove', (e) => {
      e.preventDefault();
      const t = e.touches[0];
      const rect = pad.getBoundingClientRect();

      reticle.style.left = (t.clientX - rect.left) + 'px';
      reticle.style.top = (t.clientY - rect.top) + 'px';

      if (e.touches.length === 1) {
        if (mode === 'trackpad') {
          const dx = (t.clientX - lastX) * 1.6;
          const dy = (t.clientY - lastY) * 1.6;
          if (Math.abs(dx) > 0.5 || Math.abs(dy) > 0.5) {
            hasMoved = true;
            send({ type: 'move', dx, dy });
          }
        } else {
          const u = Math.max(0, Math.min(1, (t.clientX - rect.left) / rect.width));
          const v = Math.max(0, Math.min(1, (t.clientY - rect.top) / rect.height));
          send({ type: 'abs', u, v });
        }
      } else if (e.touches.length === 2) {
        // Two-finger scroll
        const dy = (t.clientY - lastY) * 1.5;
        send({ type: 'scroll', scrollDy: -Math.round(dy) });
      }

      lastX = t.clientX;
      lastY = t.clientY;
    });

    pad.addEventListener('touchend', (e) => {
      e.preventDefault();
      reticle.style.display = 'none';

      // Tap-to-click if quick touch and didn't drag far
      const duration = Date.now() - touchStartTime;
      if (!hasMoved && duration < 300) {
        if (touchCount === 1) {
          send({ type: 'click' });
        } else if (touchCount === 2) {
          send({ type: 'rclick' });
        }
      }
    });
  </script>
</body>
</html>
''';
}
