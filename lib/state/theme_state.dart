import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      orElse: () => MapEntry('Indigo', Colors.indigo),
    ).key;
  }
}

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

  void setMode(ThemeMode mode) => state = state.copyWith(mode: mode);

  void setSeedByName(String name) =>
      state = state.copyWith(seed: ThemePalette.seeds[name] ?? Colors.indigo);
}

final appThemeProvider =
StateNotifierProvider<AppThemeController, AppThemeState>(
      (ref) => AppThemeController(),
);
