import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appSettingsControllerProvider =
    StateNotifierProvider<AppSettingsController, AppSettingsState>((ref) {
      return AppSettingsController()..load();
    });

enum AppThemeMode { system, light, dark, black }

class AppSettingsState {
  const AppSettingsState({
    this.themeMode = AppThemeMode.system,
    this.showBanner = true,
    this.clickPlayerBarToLyrics = false,
    this.showChorus = true,
    this.fadeDuration = 0.2,
  });

  final AppThemeMode themeMode;
  final bool showBanner;
  final bool clickPlayerBarToLyrics;
  final bool showChorus;
  final double fadeDuration;

  ThemeMode get materialThemeMode {
    return switch (themeMode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark || AppThemeMode.black => ThemeMode.dark,
    };
  }

  AppSettingsState copyWith({
    AppThemeMode? themeMode,
    bool? showBanner,
    bool? clickPlayerBarToLyrics,
    bool? showChorus,
    double? fadeDuration,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      showBanner: showBanner ?? this.showBanner,
      clickPlayerBarToLyrics:
          clickPlayerBarToLyrics ?? this.clickPlayerBarToLyrics,
      showChorus: showChorus ?? this.showChorus,
      fadeDuration: fadeDuration ?? this.fadeDuration,
    );
  }
}

class AppSettingsController extends StateNotifier<AppSettingsState> {
  AppSettingsController() : super(const AppSettingsState());

  static const _themeModeKey = 'settings.theme_mode.v1';
  static const _showBannerKey = 'settings.show_banner.v1';
  static const _clickPlayerBarToLyricsKey =
      'settings.click_player_bar_to_lyrics.v1';
  static const _showChorusKey = 'settings.show_chorus.v1';
  static const _fadeDurationKey = 'settings.fade_duration.v1';

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    state = AppSettingsState(
      themeMode: _themeModeFromName(preferences.getString(_themeModeKey)),
      showBanner: preferences.getBool(_showBannerKey) ?? true,
      clickPlayerBarToLyrics:
          preferences.getBool(_clickPlayerBarToLyricsKey) ?? false,
      showChorus: preferences.getBool(_showChorusKey) ?? true,
      fadeDuration: preferences.getDouble(_fadeDurationKey) ?? 0.2,
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, mode.name);
  }

  Future<void> setShowBanner(bool value) async {
    state = state.copyWith(showBanner: value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_showBannerKey, value);
  }

  Future<void> setClickPlayerBarToLyrics(bool value) async {
    state = state.copyWith(clickPlayerBarToLyrics: value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_clickPlayerBarToLyricsKey, value);
  }

  Future<void> setShowChorus(bool value) async {
    state = state.copyWith(showChorus: value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_showChorusKey, value);
  }

  Future<void> setFadeDuration(double value) async {
    state = state.copyWith(fadeDuration: value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_fadeDurationKey, value);
  }

  AppThemeMode _themeModeFromName(String? value) {
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => AppThemeMode.system,
    );
  }
}
