import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pages/home_page.dart';
import 'state/app_state.dart';


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
// 应用启动后，启动数据源（默认 Mock）
    Future.microtask(() async {
      await ref.read(ingestProvider).start();
    });
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telemetry Viewer',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomePage(),
    );
  }
}