import 'dart:math' as math;


/// 标准化时间：统一为毫秒数（double）
double normalizeEpochMs(num ts) {
// 若 ts 看似秒（小于 10^12），乘以 1000
  if (ts.abs() < 1e12) return ts.toDouble() * 1000.0;
  return ts.toDouble();
}


class DataPacket {
  final double epochMs;
  final String type; // 结构体类型，如 "IMU"
  final Map<String, num> payload; // 变量名->数值
  DataPacket({required this.epochMs, required this.type, required this.payload});
}


/// 变量的唯一路径：type.payloadKey
class VariablePath {
  final String type;
  final String key;
  const VariablePath(this.type, this.key);
  String get id => '$type.$key';
  @override
  String toString() => id;
  @override
  bool operator ==(Object other) => other is VariablePath && other.id == id;
  @override
  int get hashCode => id.hashCode;
}


/// 时间序列点
class Pt { final double xMs; final double y; const Pt(this.xMs, this.y); }


/// 简单环形缓冲区（固定容量，覆盖旧数据）
class RingSeries {
  final int capacity;
  final List<Pt> _buf;
  int _start = 0; // 指向最旧
  int _len = 0;
  RingSeries(this.capacity) : _buf = List.filled(capacity, const Pt(0, 0));


  void add(Pt p) {
    final idx = (_start + _len) % capacity;
    _buf[idx] = p;
    if (_len < capacity) {
      _len++;
    } else {
      _start = (_start + 1) % capacity;
    }
  }


  Iterable<Pt> get points sync* {
    for (int i = 0; i < _len; i++) {
      yield _buf[(_start + i) % capacity];
    }
  }


  List<Pt> toList() => points.toList(growable: false);
  bool get isEmpty => _len == 0;
}