import 'package:flutter/material.dart';

/// Feste Farben für Tags. Gespeichert wird nur der Index, damit alle Geräte
/// dieselbe Farbe zeigen und das Theme sie später anpassen kann.
const List<Color> _tagPalette = [
  Color(0xFF3F6CDF), // Blau
  Color(0xFF2E9E6B), // Grün
  Color(0xFFE0782F), // Orange
  Color(0xFFC2416B), // Beere
  Color(0xFF7C4DCC), // Violett
  Color(0xFF1F9AAD), // Petrol
  Color(0xFFB08A1E), // Senf
  Color(0xFF6B7280), // Grau
];

/// Anzahl der Tag-Farben.
int get tagPaletteSize => _tagPalette.length;

/// Farbe zum gespeicherten Index; unbekannte Werte laufen im Kreis.
Color tagColor(int index) => _tagPalette[index % _tagPalette.length];

/// Gut lesbare Schriftfarbe auf [background].
Color onTagColor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
