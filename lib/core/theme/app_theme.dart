import 'package:flutter/material.dart';
import 'package:m3e_design/m3e_design.dart';

class AppTheme {
  static ThemeData lightTheme() {
    return ColorScheme.fromSeed(
      seedColor: const Color(0xFF335EEA),
      brightness: Brightness.light,
    ).toM3EThemeData();
  }

  static ThemeData darkTheme() {
    return ColorScheme.fromSeed(
      seedColor: const Color(0xFF335EEA),
      brightness: Brightness.dark,
    ).toM3EThemeData();
  }

  static ThemeData blackTheme() {
    final base = ColorScheme.fromSeed(
      seedColor: Colors.black,
      brightness: Brightness.dark,
    );
    return base.toM3EThemeData().copyWith(
      scaffoldBackgroundColor: Colors.black,
      colorScheme: base.copyWith(surface: Colors.black),
    );
  }
}
