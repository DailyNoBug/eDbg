import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import 'app_state.dart';
import 'prefs_state.dart';

class TelemetryListenerState {
  final int port;
  final bool listening;
  final int packetCount;
  final DateTime? lastPacketAt;
  final String? lastError;

  const TelemetryListenerState({
    required this.port,
    required this.listening,
    required this.packetCount,
    this.lastPacketAt,
    this.lastError,
  });

  TelemetryListenerState copyWith({
    int? port,
    bool? listening,
    int? packetCount,
    DateTime? lastPacketAt,
    Object? lastError = _sentinel,
  }) {
    return TelemetryListenerState(
      port: port ?? this.port,
      listening: listening ?? this.listening,
      packetCount: packetCount ?? this.packetCount,
      lastPacketAt: lastPacketAt ?? this.lastPacketAt,
      lastError: identical(lastError, _sentinel)
          ? this.lastError
          : lastError as String?,
    );
  }

  static TelemetryListenerState initial(int port) =>
      TelemetryListenerState(port: port, listening: false, packetCount: 0);
}

const Object _sentinel = Object();

class TelemetryListener extends StateNotifier<TelemetryListenerState> {
  TelemetryListener(this._ref)
      : super(TelemetryListenerState.initial(
          _ref.read(prefsProvider).ingestPort,
        )) {
    _portSub = _ref.listen<int>(
      prefsProvider.select((p) => p.ingestPort),
      (prev, next) => _bind(next),
      fireImmediately: true,
    );
    _pausedSub = _ref.listen<bool>(
      pausedProvider,
      (prev, next) => _handlePauseChange(next),
      fireImmediately: true,
    );
  }

  final Ref _ref;
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _socketSub;
  ProviderSubscription<int>? _portSub;
  ProviderSubscription<bool>? _pausedSub;
  bool _paused = false;
  int? _boundPort;

  final Queue<Uint8List> _queue = Queue<Uint8List>();
  bool _draining = false;
  Timer? _statusTimer;
  int _packetsPending = 0;
  DateTime? _latestPacketAt;
  bool _errorDirty = false;
  String? _nextError;

  Future<void> _bind(int port, {bool force = false}) async {
    if (!force && _boundPort == port && _socket != null) {
      return;
    }
    await _closeSocket();
    state = state.copyWith(port: port, listening: false, lastError: null);

    if (_paused) {
      return;
    }

    if (kIsWeb) {
      state = state.copyWith(
        listening: false,
        lastError: 'Web 平台不支持原生套接字监听',
      );
      return;
    }

    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
      ).timeout(const Duration(seconds: 3));
      _socket = socket;
      _boundPort = port;
      socket.readEventsEnabled = true;
      socket.broadcastEnabled = true;
      state = state.copyWith(listening: true, lastError: null);
      _socketSub = socket.listen(
        (event) {
          if (event == RawSocketEvent.read) {
            final datagram = socket.receive();
            if (datagram != null) {
              _handleDatagram(datagram.data);
            }
          }
        },
        onError: (Object err, StackTrace st) {
          _registerError(err.toString());
          state = state.copyWith(listening: false, lastError: err.toString());
        },
        onDone: () {
          state = state.copyWith(listening: false);
        },
        cancelOnError: true,
      );
    } catch (e) {
      state = state.copyWith(
        listening: false,
        lastError: '端口 $port 绑定失败: $e',
      );
    }
  }

  Future<void> applyPort(int port) async {
    await _bind(port, force: true);
  }

  void _handlePauseChange(bool next) {
    _paused = next;
    if (next) {
      unawaited(_closeSocket());
      state = state.copyWith(listening: false);
    } else {
      unawaited(_bind(state.port));
    }
  }

  void _handleDatagram(Uint8List bytes) {
    if (_paused || bytes.isEmpty) {
      return;
    }
    _queue.add(Uint8List.fromList(bytes));
    if (!_draining) {
      _draining = true;
      scheduleMicrotask(_drainQueue);
    }
  }

  Future<void> _drainQueue() async {
    while (_queue.isNotEmpty) {
      final data = _queue.removeFirst();
      await _processPacket(data);
    }
    _draining = false;
  }

  Future<void> _processPacket(Uint8List data) async {
    final text = utf8.decode(data, allowMalformed: true).trim();
    if (text.isEmpty) return;

    try {
      final decodedList = await compute(_decodePacketBundle, text);
      if (decodedList.isEmpty) {
        _registerError('收到空 JSON 数据');
        _scheduleStatusFlush();
        return;
      }

      for (final decoded in decodedList) {
        _dispatchDecoded(decoded);
      }

      _packetsPending += decodedList.length;
      _latestPacketAt = DateTime.now();
      _registerError(null);
    } catch (e) {
      _registerError('JSON 解析失败: $e');
    }

    _scheduleStatusFlush();
  }

  void _dispatchDecoded(dynamic decoded) {
    if (decoded is List) {
      for (final item in decoded) {
        _dispatchDecoded(item);
      }
      return;
    }
    if (decoded is Map<String, dynamic>) {
      final packet = _mapToPacket(decoded);
      if (packet != null) {
        _ref.read(registryProvider.notifier).ingest(packet);
        _ref.read(storeProvider.notifier).add(packet);
      }
    }
  }

  DataPacket? _mapToPacket(Map<String, dynamic> json) {
    final type = _extractType(json);
    final ts = _extractTimestamp(json);
    final payload = _extractPayload(json);
    if (payload.isEmpty) return null;
    return DataPacket(epochMs: ts, type: type, payload: payload);
  }

  String _extractType(Map<String, dynamic> json) {
    final candidates = ['type', 'topic', 'channel', 'name', 'group'];
    for (final key in candidates) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return 'default';
  }

  double _extractTimestamp(Map<String, dynamic> json) {
    final candidates = ['timestamp', 'ts', 'time', 'epoch_ms', 'epochMs'];
    for (final key in candidates) {
      final value = json[key];
      final num? parsed = _asNum(value);
      if (parsed != null) {
        return normalizeEpochMs(parsed);
      }
    }
    return DateTime.now().millisecondsSinceEpoch.toDouble();
  }

  Map<String, num> _extractPayload(Map<String, dynamic> json) {
    final result = <String, num>{};
    final nestedKeys = ['payload', 'values', 'data'];
    for (final key in nestedKeys) {
      final value = json[key];
      if (value is Map) {
        value.forEach((k, v) {
          final num? parsed = _asNum(v);
          if (parsed != null) {
            result[k.toString()] = parsed;
          }
        });
        if (result.isNotEmpty) {
          return result;
        }
      }
    }

    json.forEach((key, value) {
      if (_metaKeys.contains(key)) {
        return;
      }
      final num? parsed = _asNum(value);
      if (parsed != null) {
        result[key.toString()] = parsed;
      }
    });
    return result;
  }

  num? _asNum(dynamic value) {
    if (value is num) return value;
    if (value is String) {
      return num.tryParse(value);
    }
    return null;
  }

  void _registerError(String? message) {
    _nextError = message;
    _errorDirty = true;
  }

  void _scheduleStatusFlush() {
    _statusTimer ??= Timer(const Duration(milliseconds: 200), _flushStatus);
  }

  void _flushStatus() {
    _statusTimer?.cancel();
    _statusTimer = null;

    final bool shouldUpdateError = _errorDirty;
    if (_packetsPending == 0 && !shouldUpdateError) {
      return;
    }

    state = state.copyWith(
      packetCount: state.packetCount + _packetsPending,
      lastPacketAt: _latestPacketAt ?? state.lastPacketAt,
      lastError: shouldUpdateError ? _nextError : _sentinel,
    );

    _packetsPending = 0;
    _latestPacketAt = null;
    _errorDirty = false;
    _nextError = null;
  }

  Future<void> _closeSocket() async {
    await _socketSub?.cancel();
    _socketSub = null;
    _socket?.close();
    _socket = null;
    _boundPort = null;
    _queue.clear();
    _statusTimer?.cancel();
    _statusTimer = null;
    _draining = false;
    _packetsPending = 0;
    _latestPacketAt = null;
    _errorDirty = false;
    _nextError = null;
  }

  @override
  void dispose() {
    _portSub?.close();
    _pausedSub?.close();
    _closeSocket();
    _flushStatus();
    super.dispose();
  }
}

final telemetryListenerProvider =
    StateNotifierProvider<TelemetryListener, TelemetryListenerState>((ref) {
  final listener = TelemetryListener(ref);
  ref.onDispose(listener.dispose);
  return listener;
});

List<dynamic> _decodePacketBundle(String text) {
  final results = <dynamic>[];
  bool parsedAny = false;

  void parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    final dynamic decoded = jsonDecode(trimmed);
    parsedAny = true;
    if (decoded is List) {
      results.addAll(decoded);
    } else {
      results.add(decoded);
    }
  }

  try {
    parse(text);
  } catch (_) {
    final lines = const LineSplitter().convert(text);
    for (final line in lines) {
      try {
        parse(line);
      } catch (_) {
        // ignore individual line errors
      }
    }
  }

  if (!parsedAny) {
    throw const FormatException('无法解析 JSON 文本');
  }

  return results;
}

const Set<String> _metaKeys = {
  'timestamp',
  'ts',
  'time',
  'epoch_ms',
  'epochMs',
  'type',
  'topic',
  'channel',
  'name',
  'group',
  'payload',
  'values',
  'data',
};
