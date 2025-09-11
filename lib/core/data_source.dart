import 'dart:async';
import 'dart:convert';
import 'dart:io'
    show RawDatagramSocket, InternetAddress, Datagram, Socket, RawSocketEvent;
// FIX: Corrected 'dart.math' to 'dart:math'.
import 'dart:math' as math;
import 'models.dart';

// Assuming normalizeEpochMs is defined elsewhere and returns an int or num.
// We will handle the conversion at the call site.
int normalizeEpochMs(dynamic ts) {
  if (ts is int) {
    return ts;
  }
  if (ts is double) {
    return ts.toInt();
  }
  // Fallback, though ideally the source data is reliable.
  return DateTime.now().millisecondsSinceEpoch;
}


/// 数据源统一接口：输出 DataPacket 流
abstract class DataSource {
  Stream<DataPacket> get stream;
  Future<void> dispose();
}

/// UDP 数据源（桌面/移动）
class UdpDataSource implements DataSource {
  final int port;
  final StreamController<DataPacket> _ctrl = StreamController.broadcast();
  RawDatagramSocket? _socket;

  UdpDataSource(this.port);

  @override
  Stream<DataPacket> get stream => _ctrl.stream;

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final Datagram? d = _socket!.receive();
        if (d == null) return;
        try {
          final s = utf8.decode(d.data);
          final obj = jsonDecode(s) as Map<String, dynamic>;
          final ts = normalizeEpochMs(obj['ts']);
          final type = obj['type'] as String;
          final payload = (obj['payload'] as Map)
              .map((k, v) => MapEntry(k.toString(), v as num));
          _ctrl.add(DataPacket(
              epochMs: ts.toDouble(),
              type: type,
              payload: Map<String, num>.from(payload)));
        } catch (e, st) {
          _ctrl.addError('JSON 解析失败: $e', st);
        }
      }
    }, onError: (e, st) {
      _ctrl.addError(e, st);
    }, onDone: () {
      _ctrl.addError('UDP Socket closed');
    });
  }

  @override
  Future<void> dispose() async {
    _socket?.close();
    await _ctrl.close();
  }
}

/// TCP 数据源（按行分包）
class TcpDataSource implements DataSource {
  final String host;
  final int port;
  final StreamController<DataPacket> _ctrl = StreamController.broadcast();
  Socket? _socket;
  String _buf = '';

  TcpDataSource(this.host, this.port);

  @override
  Stream<DataPacket> get stream => _ctrl.stream;

  Future<void> start() async {
    _socket = await Socket.connect(host, port);
    _socket!
        .cast<List<int>>()
        .transform(utf8.decoder)
        .listen((data) {
      _buf += data;
      int idx;
      while ((idx = _buf.indexOf('\n')) != -1) {
        final line = _buf.substring(0, idx).trim();
        _buf = _buf.substring(idx + 1);
        if (line.isEmpty) continue;
        try {
          final obj = jsonDecode(line) as Map<String, dynamic>;
          final ts = normalizeEpochMs(obj['ts']);
          final type = obj['type'] as String;
          final payload = (obj['payload'] as Map)
              .map((k, v) => MapEntry(k.toString(), v as num));
          _ctrl.add(DataPacket(
              epochMs: ts.toDouble(),
              type: type,
              payload: Map<String, num>.from(payload)));
        } catch (e, st) {
          _ctrl.addError('JSON 解析失败: $e', st);
        }
      }
    }, onError: (e, st) {
      _ctrl.addError(e, st);
    }, onDone: () {
      _ctrl.addError('TCP 连接关闭');
    });
  }

  @override
  Future<void> dispose() async {
    _socket?.destroy();
    await _ctrl.close();
  }
}

/// 模拟数据（开发调试）
class MockDataSource implements DataSource {
  final StreamController<DataPacket> _ctrl = StreamController.broadcast();
  Timer? _timer;
  double _t = 0;

  MockDataSource();

  @override
  Stream<DataPacket> get stream => _ctrl.stream;

  void start() {
    _timer = Timer.periodic(const Duration(milliseconds: 20), (_) {
      final now = DateTime.now().millisecondsSinceEpoch.toDouble();
      _t += 0.02;
      _ctrl.add(DataPacket(epochMs: now, type: 'IMU', payload: {
        'ax': 0.5 * (1 + math.sin(_t * 2.0)),
        'ay': 0.5 * (1 + math.cos(_t * 1.3)),
        'az': 9.8 + 0.2 * math.sin(_t),
      }));
      _ctrl.add(DataPacket(epochMs: now, type: 'Motor', payload: {
        'rpm': 1000 + 200 * math.sin(_t * 0.7),
        'temp': 40 + 5 * math.cos(_t * 0.5),
      }));
    });
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _ctrl.close();
  }
}