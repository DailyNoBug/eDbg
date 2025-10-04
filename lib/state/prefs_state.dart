import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kCompact = 'prefs.compactCards';
const _kSampling = 'prefs.enableSampling';
const _kRenderer = 'prefs.renderer'; // FastLine | Line | WebGL
const _kLineWidth = 'prefs.lineWidth'; // double
const _kAutoIngest = 'prefs.autoIngest';
const _kIngestPort = 'prefs.ingestPort';

class AppPrefsState {
  final bool compactCards;
  final bool enableSampling;
  final String renderer;
  final double lineWidth;
  final bool autoIngest;
  final int ingestPort;

  const AppPrefsState({
    required this.compactCards,
    required this.enableSampling,
    required this.renderer,
    required this.lineWidth,
    required this.autoIngest,
    required this.ingestPort,
  });

  AppPrefsState copyWith({
    bool? compactCards,
    bool? enableSampling,
    String? renderer,
    double? lineWidth,
    bool? autoIngest,
    int? ingestPort,
  }) {
    return AppPrefsState(
      compactCards: compactCards ?? this.compactCards,
      enableSampling: enableSampling ?? this.enableSampling,
      renderer: renderer ?? this.renderer,
      lineWidth: lineWidth ?? this.lineWidth,
      autoIngest: autoIngest ?? this.autoIngest,
      ingestPort: ingestPort ?? this.ingestPort,
    );
  }

  static const AppPrefsState defaults = AppPrefsState(
    compactCards: true,
    enableSampling: true,
    renderer: 'FastLine',
    lineWidth: 1.5,
    autoIngest: true,
    ingestPort: 54431,
  );
}

class AppPrefsController extends StateNotifier<AppPrefsState> {
  AppPrefsController() : super(AppPrefsState.defaults);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    state = AppPrefsState(
      compactCards: p.getBool(_kCompact) ?? AppPrefsState.defaults.compactCards,
      enableSampling:
          p.getBool(_kSampling) ?? AppPrefsState.defaults.enableSampling,
      renderer: p.getString(_kRenderer) ?? AppPrefsState.defaults.renderer,
      lineWidth: p.getDouble(_kLineWidth) ?? AppPrefsState.defaults.lineWidth,
      autoIngest: p.getBool(_kAutoIngest) ?? AppPrefsState.defaults.autoIngest,
      ingestPort: p.getInt(_kIngestPort) ?? AppPrefsState.defaults.ingestPort,
    );
  }

  Future<void> _persist(void Function(SharedPreferences p) edit) async {
    final p = await SharedPreferences.getInstance();
    edit(p);
  }

  void setCompactCards(bool v) {
    state = state.copyWith(compactCards: v);
    _persist((p) => p.setBool(_kCompact, v));
  }

  void setEnableSampling(bool v) {
    state = state.copyWith(enableSampling: v);
    _persist((p) => p.setBool(_kSampling, v));
  }

  void setRenderer(String v) {
    state = state.copyWith(renderer: v);
    _persist((p) => p.setString(_kRenderer, v));
  }

  void setLineWidth(double v) {
    state = state.copyWith(lineWidth: v);
    _persist((p) => p.setDouble(_kLineWidth, v));
  }

  void setAutoIngest(bool v) {
    state = state.copyWith(autoIngest: v);
    _persist((p) => p.setBool(_kAutoIngest, v));
  }

  void setIngestPort(int v) {
    state = state.copyWith(ingestPort: v);
    _persist((p) => p.setInt(_kIngestPort, v));
  }
}

final prefsProvider = StateNotifierProvider<AppPrefsController, AppPrefsState>(
  (ref) => AppPrefsController(),
);
