import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class ConnectivityProvider extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();

  bool _isConnected = true;
  Timer? _timer;

  bool get isConnected => _isConnected;

  static const _testUrl = 'https://cloudflare.com/cdn-cgi/trace';

  void initialize() {
    _listenToChanges();
    _startPeriodicCheck();
    _updateStatus(); // initial check
  }

  void _listenToChanges() {
    _connectivity.onConnectivityChanged.listen((results) {
      if (results.isNotEmpty) {
        _updateStatus(results.first);
      }
    });
  }

  Future<void> _updateStatus([ConnectivityResult? result]) async {
    final hasNetwork = result != ConnectivityResult.none;

    if (!hasNetwork) {
      _setStatus(false);
      return;
    }

    final online = await _ping();
    _setStatus(online);
  }

  Future<bool> _ping() async {
    try {
      final res = await http
          .head(Uri.parse(_testUrl))
          .timeout(const Duration(seconds: 3));

      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  void _setStatus(bool value) {
    if (_isConnected != value) {
      _isConnected = value;
      notifyListeners();
    }
  }

  void _startPeriodicCheck() {
    const seconds = kIsWeb ? 3 : 6;

    _timer = Timer.periodic(const Duration(seconds: seconds), (_) {
      _updateStatus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
