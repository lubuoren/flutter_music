import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:m3e_design/m3e_design.dart';

class AppTheme {
  static const _seedColor = Color(0xFF335EEA);

  static ThemeData lightTheme([ColorScheme? dynamicScheme]) {
    return (dynamicScheme ??
            ColorScheme.fromSeed(
              seedColor: _seedColor,
              brightness: Brightness.light,
            ))
        .harmonized()
        .toM3EThemeData();
  }

  static ThemeData darkTheme([ColorScheme? dynamicScheme]) {
    return (dynamicScheme ??
            ColorScheme.fromSeed(
              seedColor: _seedColor,
              brightness: Brightness.dark,
            ))
        .harmonized()
        .toM3EThemeData();
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
