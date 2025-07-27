import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.white,
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: Colors.blue,
        unselectedLabelColor: Colors.white,
        indicatorColor: Colors.blue,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(
          fontSize: 12,
          color: Colors.white,
        ),
      ),
      cardTheme: CardTheme(
        color: Colors.grey[900],
        elevation: 2,
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.grey,
      ),
    );
  }
}
