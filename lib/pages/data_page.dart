import 'dart:collection';
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
  late List<_ChartGroup> _groups;
  int _chartCounter = 1;
  final Set<String> _pausedCharts = <String>{};
  final Map<String, Map<VariablePath, List<_ChartPoint>>> _pausedSnapshots =
      <String, Map<VariablePath, List<_ChartPoint>>>{};
  final Map<VariablePath, _LiveSeriesCache> _liveCaches =
      <VariablePath, _LiveSeriesCache>{};
  static const int _liveWindowSeconds = 12;
  static const int _maxSamplesPerSeries = _liveWindowSeconds * 50;

  @override
  void initState() {
    super.initState();
    _groups = [_ChartGroup(id: _nextGroupId())];
    _applySelection(ref.read(selectedVarsProvider));
  }

  void _syncSelection(Set<VariablePath> selection) {
    if (!mounted) return;
    setState(() {
      _applySelection(selection);
    });
  }

  void _applySelection(Set<VariablePath> selection) {
    final store = ref.read(storeProvider).series;
    if (selection.isEmpty) {
      _groups
        ..clear()
        ..add(_ChartGroup(id: _nextGroupId()));
      _pausedCharts.clear();
      _pausedSnapshots.clear();
      _liveCaches.clear();
      return;
    }

    for (final group in _groups) {
      group.variables.removeWhere((vp) => !selection.contains(vp));
    }

    final assigned = <VariablePath>{};
    for (final group in _groups) {
      assigned.addAll(group.variables);
    }

    if (_groups.isEmpty) {
      _groups.add(_ChartGroup(id: _nextGroupId()));
    }

    for (final vp in selection) {
      if (!assigned.contains(vp)) {
        _groups.first.variables.add(vp);
      }
    }

    if (_groups.length > 1) {
      for (var i = _groups.length - 1; i >= 0; i--) {
        if (_groups[i].variables.isEmpty && i != 0) {
          _groups.removeAt(i);
        }
      }
    }

    final existingIds = _groups.map((g) => g.id).toSet();
    _pausedCharts.removeWhere((id) => !existingIds.contains(id));
    _pausedSnapshots.removeWhere((id, _) => !existingIds.contains(id));
    _liveCaches.removeWhere((vp, _) => !selection.contains(vp));

    for (final group in _groups) {
      if (_pausedCharts.contains(group.id)) {
        _pausedSnapshots[group.id] = _collectSeriesData(group.variables, store);
      }
    }
  }

  String _nextGroupId() => 'chart-${_chartCounter++}';

  @override
  Widget build(BuildContext context) {
    ref.listen<Set<VariablePath>>(selectedVarsProvider, (previous, next) {
      if (previous == next) return;
      _syncSelection(next);
    });

    final cs = Theme.of(context).colorScheme;
    final listener = ref.watch(telemetryListenerProvider);
    final registry = ref.watch(registryProvider);
    final store = ref.watch(storeProvider).series;
    final selected = ref.watch(selectedVarsProvider);
    final prefs = ref.watch(prefsProvider);
    final paused = ref.watch(pausedProvider);

    final sortedTypes = registry.keys.toList()..sort();

    final sidebar = _Sidebar(
      listener: listener,
      registry: registry,
      sortedTypes: sortedTypes,
      selected: selected,
      onToggle: _toggleSelection,
      onClear: _clearSelection,
      paused: paused,
      onTogglePaused: () => _togglePaused(paused),
    );

    final chartArea = _buildChartArea(
      context: context,
      cs: cs,
      listener: listener,
      selected: selected,
      store: store,
      prefs: prefs,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('数据监控')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isVertical = constraints.maxWidth < 820;
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
    required TelemetryListenerState listener,
    required Set<VariablePath> selected,
    required Map<VariablePath, RingSeries> store,
    required AppPrefsState prefs,
  }) {
    if (selected.isEmpty) {
      final subtitle = listener.packetCount > 0
          ? '在左侧选择要监控的信号，可拖动拆分到不同图表'
          : '等待数据到达后，可在左侧选择信号并拖动拆分图表';
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
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: _groups.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index < _groups.length) {
                  final group = _groups[index];
                  return _buildChartPanel(
                    context: context,
                    cs: cs,
                    group: group,
                    index: index,
                    store: store,
                    prefs: prefs,
                  );
                }

                return _buildCreateZone(context, cs);
              },
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: DragTarget<VariablePath>(
              onWillAcceptWithDetails: (details) => true,
              onAcceptWithDetails: (details) =>
                  setState(() => _moveVariableToNewChart(details.data)),
              builder: (context, candidate, rejected) {
                final active = candidate.isNotEmpty;
                return OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: active ? cs.primary : cs.outlineVariant,
                      width: active ? 2 : 1,
                    ),
                    backgroundColor:
                        active ? cs.primary.withOpacity(0.08) : null,
                  ),
                  onPressed: () => setState(() => _addChart()),
                  icon: const Icon(Icons.add),
                  label: const Text('新增图表'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartPanel({
    required BuildContext context,
    required ColorScheme cs,
    required _ChartGroup group,
    required int index,
    required Map<VariablePath, RingSeries> store,
    required AppPrefsState prefs,
  }) {
    final isPaused = _pausedCharts.contains(group.id);
    Map<VariablePath, List<_ChartPoint>> data;
    if (isPaused) {
      data = _pausedSnapshots[group.id] ??=
          _collectSeriesData(group.variables, store);
    } else {
      data = _collectLiveSeriesData(group.variables, store);
      _pausedSnapshots.remove(group.id);
    }
    final series = _seriesFromData(data, prefs);

    return DragTarget<VariablePath>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) =>
          setState(() => _assignVariableToGroup(details.data, index)),
      builder: (context, candidate, rejected) {
        final highlight = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlight ? cs.primary : Colors.transparent,
              width: highlight ? 2 : 0,
            ),
          ),
          child: Card(
            elevation: highlight ? 2 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('图表 ${index + 1}',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(width: 8),
                      if (group.variables.isNotEmpty)
                        Text('(${group.variables.length} 条曲线)',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      const Spacer(),
                      Tooltip(
                        message: isPaused ? '恢复更新' : '暂停更新',
                        child: IconButton(
                          icon: Icon(
                            isPaused ? Icons.play_arrow : Icons.pause,
                          ),
                          onPressed: () => _toggleChartPaused(group.id),
                        ),
                      ),
                      if (group.variables.isEmpty && _groups.length > 1)
                        Tooltip(
                          message: '删除空图表',
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setState(() => _removeChart(index)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildVariableChips(context, group),
                  const SizedBox(height: 12),
                  Container(
                    height: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: _buildChartBody(
                      context: context,
                      cs: cs,
                      series: series,
                      hasData: series.isNotEmpty,
                      chartId: group.id,
                      paused: isPaused,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreateZone(BuildContext context, ColorScheme cs) {
    return DragTarget<VariablePath>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) =>
          setState(() => _moveVariableToNewChart(details.data)),
      builder: (context, candidate, rejected) {
        final active = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? cs.primary : cs.outlineVariant.withOpacity(0.4),
              width: active ? 2 : 1,
            ),
            color: active ? cs.primary.withOpacity(0.08) : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Text(
            active ? '松开以创建新图表' : '拖动信号到空白处可自动建图',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        );
      },
    );
  }

  Widget _buildVariableChips(BuildContext context, _ChartGroup group) {
    if (group.variables.isEmpty) {
      return Text(
        '拖动选中的信号到下方图表区域进行显示',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final vp in group.variables)
          LongPressDraggable<VariablePath>(
            data: vp,
            feedback: Material(
              color: Colors.transparent,
              child: Chip(
                label: Text(vp.id),
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.12),
              ),
            ),
            child: InputChip(
              label: Text(vp.id),
              tooltip: vp.id,
              onDeleted: () => _toggleSelection(vp, false),
            ),
          ),
      ],
    );
  }

  Widget _buildChartBody({
    required BuildContext context,
    required ColorScheme cs,
    required List<CartesianSeries<_ChartPoint, DateTime>> series,
    required bool hasData,
    required String chartId,
    required bool paused,
  }) {
    if (!hasData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_chart,
                size: 40, color: cs.onSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(
              '拖动信号到此区域',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        SfCartesianChart(
          key: ValueKey(chartId),
          legend: const Legend(
            isVisible: true,
            overflowMode: LegendItemOverflowMode.wrap,
          ),
          tooltipBehavior: TooltipBehavior(
            enable: true,
            activationMode: ActivationMode.singleTap,
            header: '',
            decimalPlaces: 3,
          ),
          zoomPanBehavior: ZoomPanBehavior(
            enablePinching: true,
            enablePanning: true,
            enableDoubleTapZooming: true,
            enableMouseWheelZooming: true,
            enableSelectionZooming: true,
            zoomMode: ZoomMode.x,
          ),
          plotAreaBorderWidth: 0,
          primaryXAxis: DateTimeAxis(
            intervalType: DateTimeIntervalType.auto,
            dateFormat: DateFormat.Hms(),
            majorGridLines: const MajorGridLines(width: 0.5),
            autoScrollingMode: AutoScrollingMode.end,
            autoScrollingDeltaType: DateTimeIntervalType.seconds,
            autoScrollingDelta: _liveWindowSeconds,
          ),
          primaryYAxis: const NumericAxis(
            majorGridLines: MajorGridLines(width: 0.5),
            axisLine: AxisLine(width: 0),
          ),
          series: series,
        ),
        if (paused)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pause_circle, color: cs.primary, size: 40),
                    const SizedBox(height: 8),
                    Text('图表已暂停',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: cs.onSurface)),
                  ],
                ),
              ),
            ),
          ),
      ],
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

  void _togglePaused(bool paused) {
    ref.read(pausedProvider.notifier).state = !paused;
  }

  void _clearSelection() {
    ref.read(selectedVarsProvider.notifier).state = <VariablePath>{};
  }

  void _addChart() {
    _groups.add(_ChartGroup(id: _nextGroupId()));
  }

  void _removeChart(int index) {
    if (_groups.length <= 1) return;
    if (index < 0 || index >= _groups.length) return;
    final removed = _groups.removeAt(index);
    _pausedCharts.remove(removed.id);
    _pausedSnapshots.remove(removed.id);
  }

  void _assignVariableToGroup(VariablePath vp, int targetIndex) {
    if (_groups.isEmpty) {
      _groups.add(_ChartGroup(id: _nextGroupId()));
    }

    for (final group in _groups) {
      group.variables.remove(vp);
      if (group.variables.isEmpty) {
        _pausedSnapshots.remove(group.id);
        _pausedCharts.remove(group.id);
      }
    }

    final int clampedIndex;
    if (targetIndex < 0) {
      clampedIndex = 0;
    } else if (targetIndex >= _groups.length) {
      clampedIndex = _groups.length - 1;
    } else {
      clampedIndex = targetIndex;
    }
    final group = _groups[clampedIndex];
    if (!group.variables.contains(vp)) {
      group.variables.add(vp);
    }
    if (_pausedCharts.contains(group.id)) {
      final store = ref.read(storeProvider).series;
      _pausedSnapshots[group.id] = _collectSeriesData(group.variables, store);
    }
  }

  void _moveVariableToNewChart(VariablePath vp) {
    for (final group in _groups) {
      group.variables.remove(vp);
      if (group.variables.isEmpty) {
        _pausedSnapshots.remove(group.id);
        _pausedCharts.remove(group.id);
      }
    }
    _groups.add(_ChartGroup(id: _nextGroupId(), variables: [vp]));
  }

  void _toggleChartPaused(String id) {
    setState(() {
      if (_pausedCharts.remove(id)) {
        _pausedSnapshots.remove(id);
      } else {
        _ChartGroup? target;
        for (final g in _groups) {
          if (g.id == id) {
            target = g;
            break;
          }
        }
        final group = target;
        if (group == null) {
          return;
        }
        final store = ref.read(storeProvider).series;
        _pausedCharts.add(id);
        _pausedSnapshots[id] = _collectSeriesData(group.variables, store);
      }
    });
  }

  Map<VariablePath, List<_ChartPoint>> _collectLiveSeriesData(
    List<VariablePath> variables,
    Map<VariablePath, RingSeries> store,
  ) {
    final result = <VariablePath, List<_ChartPoint>>{};
    for (final vp in variables) {
      final ring = store[vp];
      if (ring == null || ring.isEmpty) {
        _liveCaches.remove(vp);
        continue;
      }
      final cache = _liveCaches.putIfAbsent(
          vp, () => _LiveSeriesCache(_maxSamplesPerSeries));
      cache.sync(ring);
      result[vp] = cache.view;
    }
    return result;
  }

  Map<VariablePath, List<_ChartPoint>> _collectSeriesData(
    List<VariablePath> variables,
    Map<VariablePath, RingSeries> store,
  ) {
    final result = <VariablePath, List<_ChartPoint>>{};
    for (final vp in variables) {
      final ring = store[vp];
      if (ring == null || ring.isEmpty) continue;
      result[vp] = [
        for (final pt in ring.points)
          _ChartPoint(
            DateTime.fromMillisecondsSinceEpoch(pt.xMs.round()),
            pt.y,
          ),
      ];
    }
    return result;
  }

  List<CartesianSeries<_ChartPoint, DateTime>> _seriesFromData(
    Map<VariablePath, List<_ChartPoint>> data,
    AppPrefsState prefs,
  ) {
    final renderer = prefs.renderer;
    final lineWidth = prefs.lineWidth;
    final entries = data.entries.toList()
      ..sort((a, b) => a.key.id.compareTo(b.key.id));
    final result = <CartesianSeries<_ChartPoint, DateTime>>[];
    for (final entry in entries) {
      if (entry.value.isEmpty) continue;
      result.add(_seriesFor(renderer, entry.value, entry.key.id, lineWidth));
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
    required this.paused,
    required this.onTogglePaused,
  });

  final TelemetryListenerState listener;
  final Map<String, Set<String>> registry;
  final List<String> sortedTypes;
  final Set<VariablePath> selected;
  final void Function(VariablePath vp, bool enabled) onToggle;
  final VoidCallback onClear;
  final bool paused;
  final VoidCallback onTogglePaused;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool active = listener.listening && !paused;
    final statusColor = paused
        ? cs.tertiary
        : active
            ? cs.primary
            : cs.error;
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
                            paused
                                ? Icons.pause_circle
                                : active
                                    ? Icons.wifi_tethering
                                    : Icons.portable_wifi_off,
                            color: statusColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            paused
                                ? '已暂停'
                                : active
                                    ? '运行中'
                                    : '未开启',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          FilledButton.tonalIcon(
                            onPressed: onTogglePaused,
                            icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                            label: Text(paused ? '启动' : '暂停'),
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

class _ChartGroup {
  _ChartGroup({required this.id, List<VariablePath>? variables})
      : variables = variables != null ? List.of(variables) : <VariablePath>[];

  final String id;
  final List<VariablePath> variables;
}

class _LiveSeriesCache {
  _LiveSeriesCache(this.maxSamples);

  final int maxSamples;
  final List<_ChartPoint> _buffer = <_ChartPoint>[];
  int _start = 0;
  int _lastSample = -1;

  late final List<_ChartPoint> view = _LiveSeriesView(this);

  static const int _trimThresholdMultiplier = 4;

  void sync(RingSeries ring) {
    final latestTotal = ring.totalWritten;
    if (ring.isEmpty) {
      _reset();
      return;
    }

    final oldestIndex = latestTotal - ring.length;
    final expectedLatest = latestTotal - 1;

    if (_lastSample < oldestIndex - 1) {
      _buffer.clear();
      ring.forEachPoint((x, y) {
        _buffer.add(_ChartPoint(
          DateTime.fromMillisecondsSinceEpoch(x.round()),
          y,
        ));
      });
      final overflow = _buffer.length - maxSamples;
      if (overflow > 0) {
        _start = overflow;
      }
    } else {
      ring.forEachSince(_lastSample, (x, y) {
        _buffer.add(_ChartPoint(
          DateTime.fromMillisecondsSinceEpoch(x.round()),
          y,
        ));
      });
    }

    _lastSample = expectedLatest;

    final liveLength = _buffer.length - _start;
    final overflow = liveLength - maxSamples;
    if (overflow > 0) {
      _start += overflow;
      final trimThreshold = maxSamples * _trimThresholdMultiplier;
      if (_start >= trimThreshold) {
        _buffer.removeRange(0, _start);
        _start = 0;
      }
    }
  }

  void _reset() {
    _buffer.clear();
    _start = 0;
    _lastSample = -1;
  }
}

class _LiveSeriesView extends ListBase<_ChartPoint> {
  _LiveSeriesView(this.cache);

  final _LiveSeriesCache cache;

  @override
  int get length => cache._buffer.length - cache._start;

  @override
  _ChartPoint operator [](int index) => cache._buffer[cache._start + index];

  @override
  void operator []=(int index, _ChartPoint value) =>
      throw UnsupportedError('read-only');

  @override
  set length(int newLength) => throw UnsupportedError('read-only');
}
