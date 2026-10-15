import 'package:flutter/material.dart';
import 'ui.dart';

ThemeData buildPilotTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Roboto',
  scaffoldBackgroundColor: canvas,
  splashFactory: InkSparkle.splashFactory,
  colorScheme: ColorScheme.fromSeed(
    seedColor: green,
    primary: green,
    surface: Colors.white,
  ),
  dividerTheme: const DividerThemeData(color: line, thickness: 1),
  visualDensity: VisualDensity.standard,
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: green,
    selectionColor: Color(0xFFDADFFC),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: Colors.white,
    selectedColor: softGreen,
    checkmarkColor: green,
    side: const BorderSide(color: line),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    labelStyle: const TextStyle(
      fontFamily: 'Roboto',
      color: ink,
      fontWeight: FontWeight.w700,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontFamily: 'Roboto', color: ink, height: 1.4),
    bodyLarge: TextStyle(fontFamily: 'Roboto', color: ink, height: 1.4),
    titleLarge: TextStyle(
      fontFamily: 'Roboto',
      color: ink,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'Roboto',
      color: ink,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.8,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: ink,
    elevation: 0,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    hintStyle: const TextStyle(fontFamily: 'Roboto', color: muted),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: green, width: 1.6),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 16),
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: ink,
      borderRadius: BorderRadius.circular(8),
    ),
    textStyle: const TextStyle(
      fontFamily: 'Roboto',
      color: Colors.white,
      fontSize: 12,
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(110, 48),
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(minimumSize: const Size(90, 48)),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(105, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: softGreen,
    labelTextStyle: WidgetStateProperty.all(
      const TextStyle(
        fontFamily: 'Roboto',
        color: ink,
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  ),
);
