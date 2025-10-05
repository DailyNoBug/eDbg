import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:typed_data';
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
        lastError: 'Web 楠炲啿褰存稉宥嗘暜閹镐礁甯悽鐔奉殰閹恒儱鐡ч惄鎴濇儔',
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
        lastError: '缁旑垰褰?$port 缂佹垵鐣炬径杈Е: $e',
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

    if (_pendingDecodeJobs >= _maxPendingDecodeJobs) {
      _droppedDecodeJobs++;
      if (_droppedDecodeJobs % 1000 == 0) {
        _registerError('Decoder backlog exceeded; dropped import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:typed_data';
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
        lastError: 'Web 楠炲啿褰存稉宥嗘暜閹镐礁甯悽鐔奉殰閹恒儱鐡ч惄鎴濇儔',
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
        lastError: '缁旑垰褰?$port 缂佹垵鐣炬径杈Е: $e',
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

    if (_pendingDecodeJobs >= _maxPendingDecodeJobs) {
      _droppedDecodeJobs++;
      if (_droppedDecodeJobs % 1000 == 0) {
        _registerError('Decoder backlog exceeded; dropped $_droppedDecodeJobs packets');
        _scheduleStatusFlush();
      }
      return;
    }

    _pendingDecodeJobs++;
    _decodePool
        .then((pool) => pool.submit(bytes))
        .then((normalized) {
      if (_paused) {
        return;
      }
      if (normalized.isEmpty) {
        _registerError('Received empty JSON payload');
        return;
      }

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
    unawaited(_decodePool.then((pool) => pool.dispose()));
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

List<Map<String, dynamic>> _decodePacketBundle(Uint8List bytes) {
  final results = <Map<String, dynamic>>[];
  var parsedAny = false;

  void parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    final decoded = jsonDecode(trimmed);
    parsedAny = true;
    _collectNormalized(decoded, results);
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
    throw const FormatException('閺冪姵纭剁憴锝嗙€?JSON 閺傚洦婀?);
  }

  return results;
}

void _collectNormalized(dynamic decoded, List<Map<String, dynamic>> output) {
  if (decoded is List) {
    for (final item in decoded) {
      _collectNormalized(item, output);
    }
    return;
  }

  final normalized = _normalizeTelemetry(decoded);
  if (normalized != null) {
    output.add(normalized);
  }
}

Map<String, dynamic>? _normalizeTelemetry(dynamic raw) {
  if (raw is! Map) {
    return null;
  }

  final map = <String, dynamic>{};
  raw.forEach((key, value) {
    map[key.toString()] = value;
  });

  final payload = _extractPayload(map);
  if (payload.isEmpty) {
    return null;
  }

  return {
    'type': _extractType(map),
    'epochMs': _extractTimestamp(map),
    'payload': payload,
  };
}

String _extractType(Map<String, dynamic> json) {
  const candidates = ['type', 'topic', 'channel', 'name', 'group'];
  for (final key in candidates) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return 'default';
}

double _extractTimestamp(Map<String, dynamic> json) {
  const candidates = ['timestamp', 'ts', 'time', 'epoch_ms', 'epochMs'];
  for (final key in candidates) {
    final value = json[key];
    final num? parsed = _asNum(value);
    if (parsed != null) {
      return normalizeEpochMs(parsed);
    }
  }
  return DateTime.now().millisecondsSinceEpoch.toDouble();
}

Map<String, double> _extractPayload(Map<String, dynamic> json) {
  final result = <String, double>{};
  const nestedKeys = ['payload', 'values', 'data'];
  for (final key in nestedKeys) {
    final value = json[key];
    if (value is Map) {
      value.forEach((k, v) {
        final num? parsed = _asNum(v);
        if (parsed != null) {
          result[k.toString()] = parsed.toDouble();
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
      result[key] = parsed.toDouble();
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
class _DecodeWorkerPool {
  _DecodeWorkerPool._(this._resultPort, this._workerPorts, this._isolates) {
    _resultSub = _resultPort.listen(_handleResult, onError: (_) {});
  }

  final ReceivePort _resultPort;
  late final StreamSubscription _resultSub;
  final List<SendPort> _workerPorts;
  final List<Isolate> _isolates;
  final Map<int, Completer<List<Map<String, dynamic>>>> _pending = {};
  int _nextWorker = 0;
  int _nextJobId = 0;
  bool _closed = false;

  static Future<_DecodeWorkerPool> create({int? workerCount}) async {
    final resultPort = ReceivePort();
    final workerPorts = <SendPort>[];
    final isolates = <Isolate>[];
    final pool = _DecodeWorkerPool._(resultPort, workerPorts, isolates);

    final processors = Platform.numberOfProcessors;
    final count = workerCount ?? (processors > 1 ? processors - 1 : 1);
    for (var i = 0; i < count; i++) {
      final readyPort = ReceivePort();
      final isolate = await Isolate.spawn(
        _decodeWorker,
        [resultPort.sendPort, readyPort.sendPort],
      );
      isolates.add(isolate);
      final sendPort = await readyPort.first as SendPort;
      workerPorts.add(sendPort);
      readyPort.close();
    }

    return pool;
  }

  Future<List<Map<String, dynamic>>> submit(Uint8List data) {
    if (_closed) {
      throw StateError('Decode pool closed');
    }
    final jobId = _nextJobId++;
    final completer = Completer<List<Map<String, dynamic>>>();
    _pending[jobId] = completer;

    final worker = _workerPorts[_nextWorker];
    _nextWorker = (_nextWorker + 1) % _workerPorts.length;

    final transferable = TransferableTypedData.fromList([Uint8List.fromList(data)]);
    worker.send([jobId, transferable]);
    return completer.future;
  }

  void _handleResult(dynamic message) {
    if (message is! List || message.length != 3) {
      return;
    }
    final jobId = message[0] as int;
    final result = message[1];
    final String? error = message[2] as String?;
    final completer = _pending.remove(jobId);
    if (completer == null) {
      return;
    }
    if (error != null) {
      completer.completeError(StateError(error));
    } else {
      completer.complete((result as List).cast<Map<String, dynamic>>());
    }
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    for (final port in _workerPorts) {
      port.send(null);
    }
    for (final isolate in _isolates) {
      isolate.kill(priority: Isolate.immediate);
    }
    await _resultSub.cancel();
    _resultPort.close();
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.complete(<Map<String, dynamic>>[]);
      }
    }
    _pending.clear();
  }
}

void _decodeWorker(List<dynamic> args) {
  final SendPort resultPort = args[0] as SendPort;
  final SendPort readyPort = args[1] as SendPort;
  final receivePort = ReceivePort();
  readyPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    if (message == null) {
      receivePort.close();
      Isolate.exit();
    }
    final int jobId = message[0] as int;
    final TransferableTypedData data = message[1] as TransferableTypedData;
    try {
      final Uint8List bytes = data.materialize().asUint8List();
      final normalized = _decodePacketBundle(bytes);
      resultPort.send([jobId, normalized, null]);
    } catch (e) {
      resultPort.send([jobId, null, e.toString()]);
    }
  });
}
droppedDecodeJobs packets');
        _scheduleStatusFlush();
      }
      return;
    }

    _pendingDecodeJobs++;
    _decodePool
        .then((pool) => pool.submit(bytes))
        .then((normalized) {
      if (_paused) {
        return;
      }
      if (normalized.isEmpty) {
        _registerError('Received empty JSON payload');
        return;
      }

      final packets = <DataPacket>[];
      for (final item in normalized) {
        final payload = (item['payload'] as Map).cast<String, double>();
        if (payload.isEmpty) {
          continue;
        }
        packets.add(DataPacket(
          epochMs: item['epochMs'] as double,
          type: item['type'] as String,
          payload: payload,
        ));
      }

      if (packets.isEmpty) {
        _registerError('Decoded payloads were empty');
        return;
      }

      _ref.read(registryProvider.notifier).ingestAll(packets);
      _ref.read(storeProvider.notifier).addAll(packets);

      _packetsPending += packets.length;
      _latestPacketAt = DateTime.now();
      _registerError(null);
    }).catchError((Object err, StackTrace st) {
      _registerError('JSON parse failed: ${err.toString()}');
    }).whenComplete(() {
      if (_pendingDecodeJobs > 0) {
        _pendingDecodeJobs--;
      }
      _scheduleStatusFlush();
    });
  }

  void _registerError(String? message) {(String? message) {
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
    unawaited(_decodePool.then((pool) => pool.dispose()));
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

List<Map<String, dynamic>> _decodePacketBundle(Uint8List bytes) {
  final results = <Map<String, dynamic>>[];
  var parsedAny = false;

  void parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    final decoded = jsonDecode(trimmed);
    parsedAny = true;
    _collectNormalized(decoded, results);
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
    throw const FormatException('閺冪姵纭剁憴锝嗙€?JSON 閺傚洦婀?);
  }

  return results;
}

void _collectNormalized(dynamic decoded, List<Map<String, dynamic>> output) {
  if (decoded is List) {
    for (final item in decoded) {
      _collectNormalized(item, output);
    }
    return;
  }

  final normalized = _normalizeTelemetry(decoded);
  if (normalized != null) {
    output.add(normalized);
  }
}

Map<String, dynamic>? _normalizeTelemetry(dynamic raw) {
  if (raw is! Map) {
    return null;
  }

  final map = <String, dynamic>{};
  raw.forEach((key, value) {
    map[key.toString()] = value;
  });

  final payload = _extractPayload(map);
  if (payload.isEmpty) {
    return null;
  }

  return {
    'type': _extractType(map),
    'epochMs': _extractTimestamp(map),
    'payload': payload,
  };
}

String _extractType(Map<String, dynamic> json) {
  const candidates = ['type', 'topic', 'channel', 'name', 'group'];
  for (final key in candidates) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return 'default';
}

double _extractTimestamp(Map<String, dynamic> json) {
  const candidates = ['timestamp', 'ts', 'time', 'epoch_ms', 'epochMs'];
  for (final key in candidates) {
    final value = json[key];
    final num? parsed = _asNum(value);
    if (parsed != null) {
      return normalizeEpochMs(parsed);
    }
  }
  return DateTime.now().millisecondsSinceEpoch.toDouble();
}

Map<String, double> _extractPayload(Map<String, dynamic> json) {
  final result = <String, double>{};
  const nestedKeys = ['payload', 'values', 'data'];
  for (final key in nestedKeys) {
    final value = json[key];
    if (value is Map) {
      value.forEach((k, v) {
        final num? parsed = _asNum(v);
        if (parsed != null) {
          result[k.toString()] = parsed.toDouble();
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
      result[key] = parsed.toDouble();
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
class _DecodeWorkerPool {
  _DecodeWorkerPool._(this._resultPort, this._workerPorts, this._isolates) {
    _resultSub = _resultPort.listen(_handleResult, onError: (_) {});
  }

  final ReceivePort _resultPort;
  late final StreamSubscription _resultSub;
  final List<SendPort> _workerPorts;
  final List<Isolate> _isolates;
  final Map<int, Completer<List<Map<String, dynamic>>>> _pending = {};
  int _nextWorker = 0;
  int _nextJobId = 0;
  bool _closed = false;

  static Future<_DecodeWorkerPool> create({int? workerCount}) async {
    final resultPort = ReceivePort();
    final workerPorts = <SendPort>[];
    final isolates = <Isolate>[];
    final pool = _DecodeWorkerPool._(resultPort, workerPorts, isolates);

    final processors = Platform.numberOfProcessors;
    final count = workerCount ?? (processors > 1 ? processors - 1 : 1);
    for (var i = 0; i < count; i++) {
      final readyPort = ReceivePort();
      final isolate = await Isolate.spawn(
        _decodeWorker,
        [resultPort.sendPort, readyPort.sendPort],
      );
      isolates.add(isolate);
      final sendPort = await readyPort.first as SendPort;
      workerPorts.add(sendPort);
      readyPort.close();
    }

    return pool;
  }

  Future<List<Map<String, dynamic>>> submit(Uint8List data) {
    if (_closed) {
      throw StateError('Decode pool closed');
    }
    final jobId = _nextJobId++;
    final completer = Completer<List<Map<String, dynamic>>>();
    _pending[jobId] = completer;

    final worker = _workerPorts[_nextWorker];
    _nextWorker = (_nextWorker + 1) % _workerPorts.length;

    final transferable = TransferableTypedData.fromList([Uint8List.fromList(data)]);
    worker.send([jobId, transferable]);
    return completer.future;
  }

  void _handleResult(dynamic message) {
    if (message is! List || message.length != 3) {
      return;
    }
    final jobId = message[0] as int;
    final result = message[1];
    final String? error = message[2] as String?;
    final completer = _pending.remove(jobId);
    if (completer == null) {
      return;
    }
    if (error != null) {
      completer.completeError(StateError(error));
    } else {
      completer.complete((result as List).cast<Map<String, dynamic>>());
    }
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    for (final port in _workerPorts) {
      port.send(null);
    }
    for (final isolate in _isolates) {
      isolate.kill(priority: Isolate.immediate);
    }
    await _resultSub.cancel();
    _resultPort.close();
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.complete(<Map<String, dynamic>>[]);
      }
    }
    _pending.clear();
  }
}

void _decodeWorker(List<dynamic> args) {
  final SendPort resultPort = args[0] as SendPort;
  final SendPort readyPort = args[1] as SendPort;
  final receivePort = ReceivePort();
  readyPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    if (message == null) {
      receivePort.close();
      Isolate.exit();
    }
    final int jobId = message[0] as int;
    final TransferableTypedData data = message[1] as TransferableTypedData;
    try {
      final Uint8List bytes = data.materialize().asUint8List();
      final normalized = _decodePacketBundle(bytes);
      resultPort.send([jobId, normalized, null]);
    } catch (e) {
      resultPort.send([jobId, null, e.toString()]);
    }
  });
}
