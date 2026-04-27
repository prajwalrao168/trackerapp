import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'constants.dart';

/// Pings the proxy server every 5 minutes while the app is running
/// to prevent Render.com free tier from sleeping (which causes a
/// ~50 second cold start penalty).
///
/// Usage: call [ProxyKeepAlive.start()] once when the app launches,
/// and [ProxyKeepAlive.stop()] when it's no longer needed.
class ProxyKeepAlive {
  static Timer? _timer;

  /// Start pinging every 5 minutes. Safe to call multiple times —
  /// duplicate calls are ignored.
  static void start() {
    if (_timer != null) return; // already running

    // Ping immediately on start (warms up the server)
    _ping();

    // Then every 5 minutes
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _ping());
    debugPrint('ProxyKeepAlive: started (every 5 min)');
  }

  /// Stop pinging (e.g. when the user logs out).
  static void stop() {
    _timer?.cancel();
    _timer = null;
    debugPrint('ProxyKeepAlive: stopped');
  }

  static Future<void> _ping() async {
    try {
      await http.get(Uri.parse('$kProxyBaseUrl/health'));
    } catch (e) {
      // Silently ignore — this is just a keep-alive, not critical
    }
  }
}
