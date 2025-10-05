import 'dart:typed_data';

/// 标准化时间：统一为毫秒数（double）
double normalizeEpochMs(num ts) {
  // 若 ts 看似秒（小于 10^12），乘以 1000
  if (ts.abs() < 1e12) return ts.toDouble() * 1000.0;
  return ts.toDouble();
}

class DataPacket {
  final double epochMs;
  final String type; // 结构体类型，如 "IMU"
  final Map<String, double> payload; // 变量名->数值
  DataPacket(
      {required this.epochMs, required this.type, required this.payload});
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
class Pt {
  final double xMs;
  final double y;
  const Pt(this.xMs, this.y);
}

/// 简单环形缓冲区（固定容量，覆盖旧数据）
class RingSeries {
  final int capacity;
  final Float64List _xBuf;
  final Float64List _yBuf;
  int _start = 0; // 指向最旧
  int _len = 0;
  int _totalWritten = 0;

  RingSeries(this.capacity)
      : assert(capacity > 0),
        _xBuf = Float64List(capacity),
        _yBuf = Float64List(capacity);

  void addSample(double xMs, double y) {
    final idx = (_start + _len) % capacity;
    _xBuf[idx] = xMs;
    _yBuf[idx] = y;
    if (_len < capacity) {
      _len++;
    } else {
      _start = (_start + 1) % capacity;
    }
    _totalWritten++;
  }

  void add(Pt p) => addSample(p.xMs, p.y);

  int get length => _len;
  bool get isEmpty => _len == 0;
  int get totalWritten => _totalWritten;

  Iterable<Pt> get points sync* {
    for (int i = 0; i < _len; i++) {
      final idx = (_start + i) % capacity;
      yield Pt(_xBuf[idx], _yBuf[idx]);
    }
  }

  void forEachPoint(void Function(double xMs, double y) visitor) {
    for (int i = 0; i < _len; i++) {
      final idx = (_start + i) % capacity;
      visitor(_xBuf[idx], _yBuf[idx]);
    }
  }

  void forEachSince(
      int afterIndex, void Function(double xMs, double y) visitor) {
    if (_len == 0) {
      return;
    }
    final oldestIndex = _totalWritten - _len;
    var start = afterIndex + 1;
    if (start < oldestIndex) {
      start = oldestIndex;
    }
    final end = _totalWritten;
    if (start >= end) {
      return;
    }
    for (int abs = start; abs < end; abs++) {
      final offset = abs - oldestIndex;
      final idx = (_start + offset) % capacity;
      visitor(_xBuf[idx], _yBuf[idx]);
    }
  }

  List<Pt> toList() => [for (final pt in points) pt];
}
