import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF1E4FA3);
  static const Color primaryDark = Color(0xFF163D80);
  static const Color background = Color(0xFFF5F7FB);
  static const Color card = Colors.white;
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,

    scaffoldBackgroundColor: background,

    colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary),

    // استخدام خط Cairo المحلي الموجود داخل التطبيق
    fontFamily: 'Cairo',

    textTheme: const TextTheme(bodyMedium: TextStyle(color: textDark)),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: textDark,
      elevation: 0,
      centerTitle: false,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
    ),
  );
}
