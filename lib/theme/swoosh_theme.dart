import 'package:flutter/material.dart';
import 'swoosh_colors.dart';

class SwooshTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: SwooshColors.fondoApp,
      colorScheme: ColorScheme.fromSeed(
        seedColor: SwooshColors.azulPrimario,
        primary: SwooshColors.azulPrimario,
        secondary: SwooshColors.azulAcento,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SwooshColors.azulMarino,
        foregroundColor: SwooshColors.blanco,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: SwooshColors.blanco,
        ),
      ),
      cardTheme: CardThemeData(
        color: SwooshColors.blanco,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: SwooshColors.azulBorde, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SwooshColors.azulPrimario,
          foregroundColor: SwooshColors.blanco,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SwooshColors.blanco,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: SwooshColors.azulBorde),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: SwooshColors.azulPrimario, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SwooshColors.blanco,
        indicatorColor: SwooshColors.azulClaro,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}