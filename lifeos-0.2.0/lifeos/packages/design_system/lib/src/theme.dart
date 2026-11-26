import 'package:flutter/material.dart';

/// Grundfarbe von LifeOS. Alle anderen Farben leitet Material 3 davon ab.
const Color lifeosSeedColor = Color(0xFF2F6F6A);

/// Theme für hellen und dunklen Modus.
ThemeData buildLifeosTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: lifeosSeedColor,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
