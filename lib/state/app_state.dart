import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';

/// 全局配置
class AppConfig {
  final String protocol; // 'udp'|'tcp'|'mock'
  final String host; // tcp 使用
  final int port; // udp/tcp 使用
  final int capacityPerVar; // 每变量最多保存点数
  const AppConfig({
    this.protocol = 'mock',
    this.host = '127.0.0.1',
    this.port = 9000,
    this.capacityPerVar = 10000,
  });

  AppConfig copyWith(
          {String? protocol, String? host, int? port, int? capacityPerVar}) =>
      AppConfig(
        protocol: protocol ?? this.protocol,
        host: host ?? this.host,
        port: port ?? this.port,
        capacityPerVar: capacityPerVar ?? this.capacityPerVar,
      );
}

final configProvider = StateProvider<AppConfig>((_) => const AppConfig());
final pausedProvider = StateProvider<bool>((_) => false);
final mergedAxesProvider = StateProvider<bool>((_) => true);

/// 变量注册表（左侧展示）
class TelemetryRegistry extends StateNotifier<Map<String, Set<String>>> {
// type -> {keys}
  TelemetryRegistry() : super(const {});

  final Map<String, Set<String>> _registry = <String, Set<String>>{};

  void ingest(DataPacket packet) => ingestAll([packet]);

  void ingestAll(Iterable<DataPacket> packets) {
    var mutated = false;
    for (final packet in packets) {
      if (packet.payload.isEmpty) continue;
      final set = _registry.putIfAbsent(packet.type, () => <String>{});
      final before = set.length;
      set.addAll(packet.payload.keys);
      if (set.length != before) {
        mutated = true;
      }
    }
    if (mutated) {
      state = Map.unmodifiable({
        for (final entry in _registry.entries)
          entry.key: Set.unmodifiable(entry.value),
      });
    }
  }
}

final registryProvider =
    StateNotifierProvider<TelemetryRegistry, Map<String, Set<String>>>(
        (_) => TelemetryRegistry());

/// 选中变量集合
final selectedVarsProvider =
    StateProvider<Set<VariablePath>>((_) => <VariablePath>{});

class TimeSeriesState {
  final UnmodifiableMapView<VariablePath, RingSeries> series;
  final int revision;

  const TimeSeriesState._(this.series, this.revision);

  factory TimeSeriesState.snapshot(
      Map<VariablePath, RingSeries> data, int revision) {
    return TimeSeriesState._(UnmodifiableMapView(data), revision);
  }

  static TimeSeriesState empty() => TimeSeriesState._(
      UnmodifiableMapView(const <VariablePath, RingSeries>{}), 0);
}

/// 序列存储：VariablePath -> RingSeries
class TimeSeriesStore extends StateNotifier<TimeSeriesState> {
  final int capacityPerVar;
  final Map<VariablePath, RingSeries> _series = <VariablePath, RingSeries>{};
  final Map<String, VariablePath> _pathCache = <String, VariablePath>{};
  Timer? _flushTimer;
  bool _dirty = false;
  int _revision = 0;

  static const _flushInterval = Duration(milliseconds: 16);

  TimeSeriesStore(this.capacityPerVar) : super(TimeSeriesState.empty()) {
    state = TimeSeriesState.snapshot(_series, _revision);
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    super.dispose();
  }

  VariablePath _resolvePath(String type, String key) {
    final id = '$type.$key';
    final existing = _pathCache[id];
    if (existing != null) return existing;
    final created = VariablePath(type, key);
    _pathCache[id] = created;
    return created;
  }

  void add(DataPacket packet) => addAll([packet]);

  void addAll(List<DataPacket> packets) {
    if (packets.isEmpty) {
      return;
    }

    var inserted = false;
    for (final packet in packets) {
      if (packet.payload.isEmpty) {
        continue;
      }
      final epoch = packet.epochMs;
      final type = packet.type;
      for (final entry in packet.payload.entries) {
        final vp = _resolvePath(type, entry.key);
        final series = _series[vp];
        final value = entry.value;
        if (series == null) {
          final ring = RingSeries(capacityPerVar);
          ring.addSample(epoch, value);
          _series[vp] = ring;
        } else {
          series.addSample(epoch, value);
        }
        inserted = true;
      }
    }

    if (inserted) {
      _dirty = true;
      _flushTimer ??= Timer(_flushInterval, _flush);
    }
  }

  void _flush() {
    _flushTimer = null;
    if (!_dirty) {
      return;
    }
    _dirty = false;
    _revision++;
    state = TimeSeriesState.snapshot(_series, _revision);
  }
}

final storeProvider =
    StateNotifierProvider<TimeSeriesStore, TimeSeriesState>((ref) {
  final cap = ref.watch(configProvider).capacityPerVar;
  return TimeSeriesStore(cap);
});
