import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// 在线 OSM 地图（无需 token）。
/// 使用官方建议的主域名，不使用 a/b/c 子域名。
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _controller = MapController();

  // 初始视图：东京站（可改）
  static const LatLng _initialCenter = LatLng(35.681236, 139.767125);
  static const double _initialZoom = 12;

  double _zoom = _initialZoom;
  LatLng _center = _initialCenter;

  void _zoomIn() => _controller.move(_center, (_zoom + 1).clamp(1.0, 19.0));
  void _zoomOut() => _controller.move(_center, (_zoom - 1).clamp(1.0, 19.0));
  void _resetView() => _controller.move(_initialCenter, _initialZoom);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('OpenStreetMap 在线')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                enableMultiFingerGestureRace: true,
              ),
              onMapEvent: (_) {
                final cam = _controller.camera;
                setState(() {
                  _center = cam.center;
                  _zoom = cam.zoom;
                });
              },
            ),
            children: [
              // ✅ OSM 官方主域名，避免使用 {s}.tile
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                // 按 OSM 规范设置你的真实包名
                userAgentPackageName: 'com.daydaynobug.sview',
                maxZoom: 19,
                retinaMode: MediaQuery.of(context).devicePixelRatio > 1.5,
              ),

              // 示例：初始位置放一个标记（可删）
              MarkerLayer(markers: const [
                Marker(
                  point: _initialCenter,
                  width: 40,
                  height: 40,
                  alignment: Alignment.topCenter,
                  child: Icon(Icons.location_on, size: 36),
                ),
              ]),

              // 署名（OSM 要求）
              RichAttributionWidget(
                attributions: const [
                  TextSourceAttribution(
                    '© OpenStreetMap contributors',
                    // onTap 可选：打开版权链接
                  ),
                ],
                popupBackgroundColor: cs.surface.withOpacity(0.9),
              ),
            ],
          ),

          // 右下角：缩放/归位
          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CircleToolButton(icon: Icons.add, tooltip: '放大', onTap: _zoomIn),
                const SizedBox(height: 10),
                _CircleToolButton(icon: Icons.remove, tooltip: '缩小', onTap: _zoomOut),
                const SizedBox(height: 10),
                _CircleToolButton(icon: Icons.my_location, tooltip: '回到初始视图', onTap: _resetView),
              ],
            ),
          ),

          // 左上角：经纬度/缩放显示
          Positioned(
            left: 12,
            top: 12 + MediaQuery.of(context).padding.top,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: DefaultTextStyle(
                style: TextStyle(color: cs.onSurface, fontSize: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.public, size: 14),
                    const SizedBox(width: 6),
                    Text('lat: ${_center.latitude.toStringAsFixed(5)}, '
                        'lng: ${_center.longitude.toStringAsFixed(5)}'),
                    const SizedBox(width: 10),
                    const Icon(Icons.zoom_in_map, size: 14),
                    const SizedBox(width: 4),
                    Text('z: ${_zoom.toStringAsFixed(1)}'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleToolButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;

  const _CircleToolButton({
    required this.icon,
    this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface.withOpacity(0.9),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip ?? '',
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 20, color: cs.onSurface),
          ),
        ),
      ),
    );
  }
}
