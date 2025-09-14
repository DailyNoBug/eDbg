import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePalette {
  static const Map<String, MaterialColor> seeds = {
    'Indigo': Colors.indigo,
    'Blue'  : Colors.blue,
    'Teal'  : Colors.teal,
    'Purple': Colors.purple,
  };

  static String nameOf(MaterialColor c) {
    return seeds.entries.firstWhere(
          (e) => e.value.value == c.value,
      orElse: () => const MapEntry('Indigo', Colors.indigo),
    ).key;
  }
}

// 持久化用的键
const _kMode = 'theme.mode';     // light | dark | system
const _kSeed = 'theme.seed';     // Indigo | Blue | Teal | Purple

class AppThemeState {
  final ThemeMode mode;
  final MaterialColor seed;
  const AppThemeState({required this.mode, required this.seed});

  AppThemeState copyWith({ThemeMode? mode, MaterialColor? seed}) =>
      AppThemeState(mode: mode ?? this.mode, seed: seed ?? this.seed);
}

class AppThemeController extends StateNotifier<AppThemeState> {
  AppThemeController()
      : super(const AppThemeState(mode: ThemeMode.light, seed: Colors.indigo));

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final modeStr = p.getString(_kMode) ?? 'light';
    final seedStr = p.getString(_kSeed) ?? 'Indigo';
    state = AppThemeState(
      mode: _strToMode(modeStr),
      seed: ThemePalette.seeds[seedStr] ?? Colors.indigo,
    );
  }

  void setMode(ThemeMode mode) {
    state = state.copyWith(mode: mode);
    _persist();
  }

  void setSeedByName(String name) {
    state = state.copyWith(seed: ThemePalette.seeds[name] ?? Colors.indigo);
    _persist();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kMode, _modeToStr(state.mode));
    await p.setString(_kSeed, ThemePalette.nameOf(state.seed));
  }

  static String _modeToStr(ThemeMode m) =>
      m == ThemeMode.dark ? 'dark' : (m == ThemeMode.system ? 'system' : 'light');
  static ThemeMode _strToMode(String s) =>
      s == 'dark' ? ThemeMode.dark : (s == 'system' ? ThemeMode.system : ThemeMode.light);
}

final appThemeProvider =
StateNotifierProvider<AppThemeController, AppThemeState>(
      (ref) => AppThemeController(),
);
