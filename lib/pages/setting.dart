import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/theme_state.dart';

class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({super.key});

  @override
  ConsumerState<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingPage> {
  bool _compactCards = true;
  bool _enableSampling = true;
  String _renderer = 'FastLine';
  double _lineWidth = 1.5;
  bool _autoIngest = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final themeState = ref.watch(appThemeProvider);
    final isDark = themeState.mode == ThemeMode.dark;
    final accentName = ThemePalette.nameOf(themeState.seed);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionCard(
              title: '外观',
              children: [
                SwitchListTile(
                  title: const Text('深色模式'),
                  subtitle: const Text('切换应用主题：深色 / 浅色'),
                  value: isDark,
                  onChanged: (v) =>
                      ref.read(appThemeProvider.notifier)
                          .setMode(v ? ThemeMode.dark : ThemeMode.light),
                ),
                ListTile(
                  title: const Text('主题色'),
                  subtitle: Text(accentName),
                  trailing: DropdownButton<String>(
                    value: accentName,
                    items: const [
                      DropdownMenuItem(value: 'Indigo', child: Text('Indigo')),
                      DropdownMenuItem(value: 'Blue',   child: Text('Blue')),
                      DropdownMenuItem(value: 'Teal',   child: Text('Teal')),
                      DropdownMenuItem(value: 'Purple', child: Text('Purple')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(appThemeProvider.notifier).setSeedByName(v);
                      }
                    },
                  ),
                ),
              ],
            ),

            _SectionCard(
              title: '图表与性能',
              children: [
                SwitchListTile(
                  title: const Text('启用数据降采样'),
                  subtitle: const Text('按视窗像素宽度抽样，提升大数据量渲染性能'),
                  value: _enableSampling,
                  onChanged: (v) => setState(() => _enableSampling = v),
                ),
                ListTile(
                  title: const Text('渲染器'),
                  subtitle: Text(_renderer),
                  trailing: DropdownButton<String>(
                    value: _renderer,
                    items: const [
                      DropdownMenuItem(value: 'FastLine', child: Text('FastLine')),
                      DropdownMenuItem(value: 'Line', child: Text('Line')),
                      DropdownMenuItem(value: 'WebGL', child: Text('WebGL（嵌入）')),
                    ],
                    onChanged: (v) => setState(() => _renderer = v ?? _renderer),
                  ),
                ),
                ListTile(
                  title: const Text('线宽'),
                  subtitle: Text('${_lineWidth.toStringAsFixed(1)} px'),
                ),
                Slider(
                  min: 0.5,
                  max: 4,
                  divisions: 7,
                  value: _lineWidth,
                  label: _lineWidth.toStringAsFixed(1),
                  onChanged: (v) => setState(() => _lineWidth = v),
                ),
              ],
            ),

            _SectionCard(
              title: '数据',
              children: [
                SwitchListTile(
                  title: const Text('启动时自动连接数据源'),
                  value: _autoIngest,
                  onChanged: (v) => setState(() => _autoIngest = v),
                ),
                ListTile(
                  title: const Text('清理缓存/临时数据'),
                  trailing: FilledButton.tonal(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已清理（示例）')),
                      );
                    },
                    child: const Text('清理'),
                  ),
                ),
              ],
            ),

            _SectionCard(
              title: '关于',
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline, color: cs.primary),
                  title: const Text('Telemetry Viewer'),
                  subtitle: const Text('示例设置页 • 你可以替换为真实的版本与构建信息'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _showLicenses(context),
                    icon: const Icon(Icons.article_outlined),
                    label: const Text('查看开源许可'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'Telemetry Viewer',
      applicationVersion: 'v1.0.0',
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                )),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }
}
