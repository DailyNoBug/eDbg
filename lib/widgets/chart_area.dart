import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../state/app_state.dart';
import '../core/models.dart';
class ChartArea extends ConsumerStatefulWidget {
  const ChartArea({super.key});
  @override
  ConsumerState<ChartArea> createState() => _ChartAreaState();
}


class _ChartAreaState extends ConsumerState<ChartArea> {
  late ZoomPanBehavior _zoomPan;
  late TrackballBehavior _trackball;


  @override
  void initState() {
    super.initState();
    _zoomPan = ZoomPanBehavior(
      enablePanning: true,
      enableMouseWheelZooming: true,
      enablePinching: true,
      zoomMode: ZoomMode.x,
    );
    _trackball = TrackballBehavior(enable: true, activationMode: ActivationMode.longPress);
  }


  @override
  Widget build(BuildContext context) {
    final merged = ref.watch(mergedAxesProvider);
    final selected = ref.watch(selectedVarsProvider).toList()..sort((a,b)=>a.id.compareTo(b.id));
    final store = ref.watch(storeProvider);


    if (selected.isEmpty) {
      return const Center(child: Text('在左侧勾选变量以开始绘图'));
    }


    if (merged) {
      return SfCartesianChart(
        primaryXAxis: DateTimeAxis(),
        legend: Legend(isVisible: true, position: LegendPosition.bottom),
        zoomPanBehavior: _zoomPan,
        trackballBehavior: _trackball,
        series: [
          for (final vp in selected)
            LineSeries<Pt, DateTime>(
              name: vp.id,
              dataSource: (store[vp]?.toList() ?? const <Pt>[]),
              xValueMapper: (p, _) => DateTime.fromMillisecondsSinceEpoch(p.xMs.toInt()),
              yValueMapper: (p, _) => p.y,
            ),
        ],
      );
    } else {
// 分离坐标轴：每个变量一个图，使用 ListView 列表
      return ListView.builder(
        itemCount: selected.length,
        itemBuilder: (context, i) {
          final vp = selected[i];
          return SizedBox(
            height: 220,
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SfCartesianChart(
                  title: ChartTitle(text: vp.id),
                  primaryXAxis: DateTimeAxis(),
                  zoomPanBehavior: _zoomPan,
                  trackballBehavior: _trackball,
                  series: [
                    LineSeries<Pt, DateTime>(
                      dataSource: (store[vp]?.toList() ?? const <Pt>[]),
                      xValueMapper: (p, _) => DateTime.fromMillisecondsSinceEpoch(p.xMs.toInt()),
                      yValueMapper: (p, _) => p.y,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
  }
}