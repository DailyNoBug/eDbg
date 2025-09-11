import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/sidebar.dart';
import '../widgets/chart_area.dart';
import '../state/app_state.dart';
class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merged = ref.watch(mergedAxesProvider);
    final paused = ref.watch(pausedProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realtime Telemetry Viewer'),
        actions: [
          IconButton(
            tooltip: paused ? '继续' : '暂停',
            onPressed: () => ref.read(pausedProvider.notifier).state = !paused,
            icon: Icon(paused ? Icons.play_arrow : Icons.pause),
          ),
          IconButton(
            tooltip: merged ? '切换为分离坐标' : '切换为合并坐标',
            onPressed: () => ref.read(mergedAxesProvider.notifier).state = !merged,
            icon: Icon(merged ? Icons.call_split : Icons.merge),
          ),
          IconButton(
            tooltip: '清空选中',
            onPressed: () => ref.read(selectedVarsProvider.notifier).state = {},
            icon: const Icon(Icons.clear_all),
          ),
          IconButton(
            tooltip: '设置',
            onPressed: () => showDialog(context: context, builder: (_) => const _SettingsDialog()),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: const Row(
        children: [
          SizedBox(width: 300, child: Drawer(child: Sidebar())),
          VerticalDivider(width: 1),
          Expanded(child: ChartArea()),
        ],
      ),
    );
  }
}
class _SettingsDialog extends ConsumerStatefulWidget {
  const _SettingsDialog();
  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}
class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  late TextEditingController _host;
  late TextEditingController _port;
  late TextEditingController _cap;
  String _protocol = 'mock';
  @override
  void initState() {
    super.initState();
    final cfg = ref.read(configProvider);
    _protocol = cfg.protocol; _host = TextEditingController(text: cfg.host);
    _port = TextEditingController(text: cfg.port.toString());
    _cap = TextEditingController(text: cfg.capacityPerVar.toString());
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: const Text('设置'),
    content: SizedBox(
    width: 420,
    child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: '协议'),
        value: _protocol,
        items: const [
          DropdownMenuItem(value: 'mock', child: Text('Mock 模拟')),
          DropdownMenuItem(value: 'udp', child: Text('UDP')),
          DropdownMenuItem(value: 'tcp', child: Text('TCP')),
        ],
        onChanged: (v) => setState(()=> _protocol = v ?? 'mock'),
      ),
      TextFormField(controller: _host, decoration: const InputDecoration(labelText: 'Host（TCP）')),
      TextFormField(controller: _port, decoration: const InputDecoration(labelText: 'Port（UDP/TCP）'), keyboardType: TextInputType.number),
      TextFormField(controller: _cap, decoration: const InputDecoration(labelText: '每变量最大点数'), keyboardType: TextInputType.number),
    ],
  ),
  ),
    actions: [
      TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('取消')),
      FilledButton(
        onPressed: () async {
          ref.read(configProvider.notifier).state = ref.read(configProvider).copyWith(
            protocol: _protocol,
            host: _host.text,
            port: int.tryParse(_port.text) ?? 9000,
            capacityPerVar: int.tryParse(_cap.text) ?? 10000,
          );
// 重启采集
          final ing = ref.read(ingestProvider);
          await ing.start();
          if (mounted) Navigator.pop(context);
        },
        child: const Text('应用'),
        )
      ],
    );
  }
}