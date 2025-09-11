import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models.dart';
import '../core/data_source.dart';

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


  AppConfig copyWith({String? protocol, String? host, int? port, int? capacityPerVar}) => AppConfig(
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
  TelemetryRegistry(): super({});
  void ingest(DataPacket p) {
    final set = state[p.type] ?? <String>{};
    set.addAll(p.payload.keys);
    state = {...state, p.type: set};
  }
}

final registryProvider = StateNotifierProvider<TelemetryRegistry, Map<String, Set<String>>>((_) => TelemetryRegistry());


/// 选中变量集合
final selectedVarsProvider = StateProvider<Set<VariablePath>>((_) => <VariablePath>{});


/// 序列存储：VariablePath -> RingSeries
class TimeSeriesStore extends StateNotifier<Map<VariablePath, RingSeries>> {
  final int capacityPerVar;
  TimeSeriesStore(this.capacityPerVar): super({});


  void ensure(VariablePath vp) {
    if (!state.containsKey(vp)) {
      state = {...state, vp: RingSeries(capacityPerVar)};
    }
  }


  void add(DataPacket p) {
    p.payload.forEach((k, v) {
      final vp = VariablePath(p.type, k);
      ensure(vp);
      state[vp]!.add(Pt(p.epochMs, v.toDouble()));
    });
// 触发监听
    state = {...state};
  }
}

final storeProvider = StateNotifierProvider<TimeSeriesStore, Map<VariablePath, RingSeries>>((ref) {
  final cap = ref.watch(configProvider).capacityPerVar;
  return TimeSeriesStore(cap);
});


/// 数据订阅控制器
class IngestController {
  final Ref ref; DataSource? _ds; StreamSubscription? _sub;
  IngestController(this.ref);


  Future<void> start() async {
    await stop();
    final cfg = ref.read(configProvider);
    switch (cfg.protocol) {
      case 'udp': _ds = UdpDataSource(cfg.port)..start(); break;
      case 'tcp': _ds = TcpDataSource(cfg.host, cfg.port)..start(); break;
      default: _ds = MockDataSource()..start();
    }
    _sub = _ds!.stream.listen((p) {
      ref.read(registryProvider.notifier).ingest(p);
      if (!ref.read(pausedProvider)) {
        ref.read(storeProvider.notifier).add(p);
      }
    }, onError: (e) {
// TODO: 用 SnackBar 或 Banner 告知错误
    });
  }

  Future<void> stop() async { await _sub?.cancel(); await _ds?.dispose(); }
}
final ingestProvider = Provider<IngestController>((ref) => IngestController(ref));