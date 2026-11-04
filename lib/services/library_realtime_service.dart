import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'app_log.dart';

enum RealtimeStatus { idle, connecting, online, offline, error }

/// One socket, one retry timer; sync on every connection recovers missed events.
class LibraryRealtimeService extends ChangeNotifier {
  final Uri uri;
  final Duration retryDelay;
  final Duration heartbeatInterval;
  final Duration connectionTimeout;
  final VoidCallback onCatalogueChanged;
  RealtimeStatus status = RealtimeStatus.idle;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;
  Timer? _heartbeat;
  Timer? _connectionTimer;
  bool _waitingForPong = false;
  bool _disposed = false;
  int _attempt = 0;

  LibraryRealtimeService({
    required this.uri,
    required this.onCatalogueChanged,
    this.retryDelay = const Duration(seconds: 2),
    this.heartbeatInterval = const Duration(seconds: 15),
    this.connectionTimeout = const Duration(seconds: 10),
  });

  void _setStatus(RealtimeStatus value) {
    if (_disposed) return;
    status = value;
    AppLog.event('realtime.${value.name}');
    notifyListeners();
  }

  Future<void> connect() async {
    if (_disposed || _channel != null) return;
    _retry?.cancel();
    final attempt = ++_attempt;
    _setStatus(RealtimeStatus.connecting);
    if (_disposed) return;
    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _subscription = channel.stream.listen(
        (data) {
          if (attempt == _attempt && !_disposed) _receive(data);
        },
        onError: (Object error) {
          if (attempt == _attempt) _lost(RealtimeStatus.offline);
        },
        onDone: () {
          if (attempt == _attempt) _lost(RealtimeStatus.offline);
        },
      );
      _connectionTimer = Timer(connectionTimeout, () {
        if (attempt == _attempt) _lost(RealtimeStatus.offline);
      });
      await channel.ready;
      if (_disposed || attempt != _attempt) return;
      _connectionTimer?.cancel();
      _waitingForPong = false;
      _setStatus(RealtimeStatus.online);
      if (_disposed || attempt != _attempt) return;
      requestSync();
      _heartbeat = Timer.periodic(heartbeatInterval, (_) {
        if (_waitingForPong) {
          _lost(RealtimeStatus.offline);
        } else {
          _waitingForPong = true;
          _send({'type': 'ping'});
        }
      });
    } catch (error) {
      if (attempt == _attempt && !_disposed) {
        AppLog.event('realtime.connect_failed', error: error);
        _lost(RealtimeStatus.offline);
      }
    }
  }

  void _receive(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      switch (message['type']) {
        case 'catalogue_changed':
          onCatalogueChanged();
          break;
        case 'pong':
          _waitingForPong = false;
          break;
        default:
          throw const FormatException('Unknown realtime event');
      }
    } catch (error) {
      AppLog.event('realtime.invalid_message', error: error);
      _lost(RealtimeStatus.error);
    }
  }

  void _send(Map<String, dynamic> data) {
    if (status != RealtimeStatus.online || _disposed) return;
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (error) {
      _lost(RealtimeStatus.offline);
    }
  }

  void requestSync() => _send({'type': 'sync'});

  void _lost(RealtimeStatus state) {
    if (_disposed) return;
    ++_attempt;
    _cleanup();
    _setStatus(state);
    if (_disposed) return;
    _retry?.cancel();
    _retry = Timer(retryDelay, connect);
  }

  void retryNow() {
    if (_disposed) return;
    ++_attempt;
    _cleanup();
    unawaited(connect());
  }

  void _cleanup() {
    _connectionTimer?.cancel();
    _heartbeat?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_channel?.sink.close());
    _subscription = null;
    _channel = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_attempt;
    _retry?.cancel();
    _cleanup();
    super.dispose();
  }
}
