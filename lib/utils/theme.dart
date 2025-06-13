import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryColor = Color(0xFF1E88E5);
  static const Color backgroundColor = Colors.white;
  static const Color textColor = Colors.black87;
  static const Color hintTextColor = Colors.grey;
  static const Color buttonColor = Colors.white;
  static const Color buttonTextColor = Colors.black87;
  static const Color errorColor = Colors.red;
}

final ThemeData appTheme = ThemeData(
  primaryColor: AppColors.primaryColor,
  scaffoldBackgroundColor: AppColors.backgroundColor,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.backgroundColor,
    elevation: 0,
    iconTheme: IconThemeData(color: AppColors.textColor),
    titleTextStyle: TextStyle(
      color: AppColors.textColor,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryColor,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
    ),
  ),
);
