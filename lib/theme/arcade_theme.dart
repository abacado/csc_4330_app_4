import 'package:flutter/material.dart';

const arcadeBackground = Color(0xFF10121F);
const arcadePanel = Color(0xFF1C2033);
const arcadeMint = Color(0xFF8EE6BD);
const arcadeMuted = Color(0xFFAEB5CC);

ThemeData buildArcadeTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: arcadeMint,
    brightness: Brightness.dark,
    surface: arcadeBackground,
    primary: arcadeMint,
  ),
  scaffoldBackgroundColor: arcadeBackground,
  fontFamily: 'monospace',
  appBarTheme: const AppBarTheme(
    backgroundColor: arcadeBackground,
    centerTitle: false,
  ),
  snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: arcadePanel,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  ),
);
