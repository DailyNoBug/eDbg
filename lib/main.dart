import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pages/home_page.dart';
import 'state/app_state.dart';
import 'pages/setting.dart';
import 'state/theme_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // 应用启动后启动数据源（默认 Mock）
    Future.microtask(() async {
      await ref.read(ingestProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);

    return MaterialApp(
      title: 'Telemetry Viewer',
      themeMode: theme.mode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: theme.seed,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: theme.seed,
        brightness: Brightness.dark,
      ),
      home: const HomeShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PageSpec {
  final String title;
  final IconData icon;
  final WidgetBuilder builder;
  const PageSpec({required this.title, required this.icon, required this.builder});
}

final List<PageSpec> pages = [
  PageSpec(title: 'home', icon: Icons.home_outlined, builder: (_) => const HomePage()),
  PageSpec(title: 'data', icon: Icons.dashboard_customize_outlined, builder: (_) => const _EmptyPage('data')),
  PageSpec(title: 'setting', icon: Icons.settings_input_component_outlined, builder: (_) => const SettingPage()),
];

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _expanded = true;

  static const double _expandedHeight = 120; // 含标题栏与菜单
  static const double _collapsedHeight = 88; // 紧凑，仅图标

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            height: _expanded ? _expandedHeight : _collapsedHeight,
            decoration: BoxDecoration(
              color: cs.surface,
              border: const Border(
                bottom: BorderSide(color: Color(0x1F000000)),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // 标题 + 折叠按钮
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.task_alt, size: 20),
                        const SizedBox(width: 8),
                        const Text('eDbg',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        IconButton(
                          tooltip: _expanded ? '收起菜单' : '展开菜单',
                          onPressed: () => setState(() => _expanded = !_expanded),
                          icon: Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                        ),
                      ],
                    ),
                  ),
                  // 菜单条（横向滚动）
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: pages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 4),
                      itemBuilder: (context, i) {
                        final selected = i == _index;
                        return _TopMenuItem(
                          expanded: _expanded,
                          icon: pages[i].icon,
                          title: pages[i].title,
                          selected: selected,
                          onTap: () => setState(() => _index = i),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: SafeArea(
              top: false,
              child: IndexedStack(
                index: _index,
                children: [for (final p in pages) Builder(builder: p.builder)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopMenuItem extends StatelessWidget {
  final bool expanded;
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _TopMenuItem({
    required this.expanded,
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected ? cs.primary.withOpacity(0.12) : Colors.transparent;
    final fg = selected ? cs.primary : cs.onSurfaceVariant;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 14 : 10,
            vertical: expanded ? 8 : 6,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: expanded ? 24 : 22),
              if (expanded) const SizedBox(height: 6),
              if (expanded)
                Text(
                  title,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPage extends StatelessWidget {
  final String title;
  const _EmptyPage(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('这是一个占位页面，你可以在这里替换为你的实际功能页面。'),
            ],
          ),
        ),
      ),
    );
  }
}
