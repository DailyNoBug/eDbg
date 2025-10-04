import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../core/models.dart';
import '../state/app_state.dart';
import '../state/prefs_state.dart';
import '../state/telemetry_listener.dart';

class DataPage extends ConsumerStatefulWidget {
  const DataPage({super.key});

  @override
  ConsumerState<DataPage> createState() => _DataPageState();
}

class _DataPageState extends ConsumerState<DataPage> {
  late final TooltipBehavior _tooltipBehavior;
  late final ZoomPanBehavior _zoomPanBehavior;

  @override
  void initState() {
    super.initState();
    _tooltipBehavior = TooltipBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,
      header: '',
      decimalPlaces: 3,
    );
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      zoomMode: ZoomMode.x,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final listener = ref.watch(telemetryListenerProvider);
    final registry = ref.watch(registryProvider);
    final store = ref.watch(storeProvider);
    final selected = ref.watch(selectedVarsProvider);
    final prefs = ref.watch(prefsProvider);

    final sortedTypes = registry.keys.toList()..sort();
    final selectedList = selected.toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    final chartSeries = _buildSeries(
      selected: selectedList,
      store: store,
      prefs: prefs,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('数据监控')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isVertical = constraints.maxWidth < 820;
          final sidebar = _Sidebar(
            listener: listener,
            registry: registry,
            sortedTypes: sortedTypes,
            selected: selected,
            onToggle: _toggleSelection,
            onClear: _clearSelection,
          );

          final chartArea = _buildChartArea(
            context: context,
            cs: cs,
            series: chartSeries,
            listener: listener,
            hasSelection: selectedList.isNotEmpty,
          );

          if (isVertical) {
            return Column(
              children: [
                Expanded(flex: 3, child: sidebar),
                const Divider(height: 1),
                Expanded(flex: 5, child: chartArea),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(width: 320, child: sidebar),
              const VerticalDivider(width: 1),
              Expanded(child: chartArea),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChartArea({
    required BuildContext context,
    required ColorScheme cs,
    required List<CartesianSeries<_ChartPoint, DateTime>> series,
    required TelemetryListenerState listener,
    required bool hasSelection,
  }) {
    if (!hasSelection) {
      final subtitle = listener.packetCount > 0
          ? '在左侧选择一个或多个数据项以绘图'
          : '等待数据到达后，可在左侧选择数据项进行绘图';
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline,
                size: 64, color: cs.onSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text('暂无选中数据', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SfCartesianChart(
        legend: const Legend(
            isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
        tooltipBehavior: _tooltipBehavior,
        zoomPanBehavior: _zoomPanBehavior,
        plotAreaBorderWidth: 0,
        primaryXAxis: DateTimeAxis(
          intervalType: DateTimeIntervalType.auto,
          dateFormat: DateFormat.Hms(),
          majorGridLines: const MajorGridLines(width: 0.5),
        ),
        primaryYAxis: NumericAxis(
          majorGridLines: const MajorGridLines(width: 0.5),
          axisLine: const AxisLine(width: 0),
        ),
        series: series,
      ),
    );
  }

  void _toggleSelection(VariablePath vp, bool enabled) {
    final current = {...ref.read(selectedVarsProvider)};
    if (enabled) {
      current.add(vp);
    } else {
      current.remove(vp);
    }
    ref.read(selectedVarsProvider.notifier).state = current;
  }

  void _clearSelection() {
    ref.read(selectedVarsProvider.notifier).state = <VariablePath>{};
  }

  List<CartesianSeries<_ChartPoint, DateTime>> _buildSeries({
    required List<VariablePath> selected,
    required Map<VariablePath, RingSeries> store,
    required AppPrefsState prefs,
  }) {
    final renderer = prefs.renderer;
    final lineWidth = prefs.lineWidth;
    final result = <CartesianSeries<_ChartPoint, DateTime>>[];

    for (final vp in selected) {
      final ring = store[vp];
      if (ring == null || ring.isEmpty) continue;

      final data = [
        for (final pt in ring.points)
          _ChartPoint(
            DateTime.fromMillisecondsSinceEpoch(pt.xMs.round()),
            pt.y,
          ),
      ];

      if (data.isEmpty) continue;
      result.add(_seriesFor(renderer, data, vp.id, lineWidth));
    }

    return result;
  }

  CartesianSeries<_ChartPoint, DateTime> _seriesFor(
    String renderer,
    List<_ChartPoint> data,
    String name,
    double lineWidth,
  ) {
    switch (renderer) {
      case 'Line':
        return LineSeries<_ChartPoint, DateTime>(
          name: name,
          dataSource: data,
          xValueMapper: (p, _) => p.time,
          yValueMapper: (p, _) => p.value,
          width: lineWidth,
          animationDuration: 0,
        );
      default:
        return FastLineSeries<_ChartPoint, DateTime>(
          name: name,
          dataSource: data,
          xValueMapper: (p, _) => p.time,
          yValueMapper: (p, _) => p.value,
          width: lineWidth,
          animationDuration: 0,
        );
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.listener,
    required this.registry,
    required this.sortedTypes,
    required this.selected,
    required this.onToggle,
    required this.onClear,
  });

  final TelemetryListenerState listener;
  final Map<String, Set<String>> registry;
  final List<String> sortedTypes;
  final Set<VariablePath> selected;
  final void Function(VariablePath vp, bool enabled) onToggle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = listener.listening ? cs.primary : cs.error;
    final packetText = listener.packetCount.toString();
    final lastPacket = listener.lastPacketAt != null
        ? DateFormat.Hms().format(listener.lastPacketAt!.toLocal())
        : '尚未收到';

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('监听状态',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            listener.listening
                                ? Icons.wifi_tethering
                                : Icons.portable_wifi_off,
                            color: statusColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            listener.listening ? '运行中' : '未开启',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _StatusLine(label: '端口', value: listener.port.toString()),
                      _StatusLine(label: '接收包', value: packetText),
                      _StatusLine(label: '最近数据', value: lastPacket),
                      if (listener.lastError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          listener.lastError!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _buildRegistryList(context),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: selected.isEmpty ? null : onClear,
                icon: const Icon(Icons.clear_all),
                label: const Text('清除选中项'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRegistryList(BuildContext context) {
    if (registry.isEmpty) {
      return Center(
        child: Text(
          '尚未发现任何数据项',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final tiles = <Widget>[];
    for (final type in sortedTypes) {
      final keys = registry[type]!.toList()..sort();
      tiles.add(
        ExpansionTile(
          key: PageStorageKey(type),
          title: Text('$type (${keys.length})'),
          children: [
            for (final key in keys)
              CheckboxListTile(
                dense: true,
                title: Text(key),
                value: selected.contains(VariablePath(type, key)),
                onChanged: (v) => onToggle(VariablePath(type, key), v ?? false),
              ),
          ],
        ),
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      child: ListView(
        padding: EdgeInsets.zero,
        children: tiles,
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
              width: 72,
              child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartPoint {
  const _ChartPoint(this.time, this.value);
  final DateTime time;
  final double value;
}
