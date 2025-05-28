import 'package:flutter/material.dart';

import '../core/app_colors.dart';

class AppTheme {
  AppTheme._();
  static final theme = ThemeData.light().copyWith(
    primaryColor: AppColors.primaryColor,
    scaffoldBackgroundColor: Colors.white,
    inputDecorationTheme: const InputDecorationTheme(
      hintStyle: TextStyle(
        color: AppColors.hintTextColor,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      border: OutlineInputBorder(gapPadding: 2),
      errorMaxLines: 2,
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: AppColors.graySecondaryBorderColor,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: AppColors.graySecondaryBorderColor,
        ),
      ),
      focusColor: AppColors.primaryColor,
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: AppColors.redAlertColor,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: AppColors.redAlertColor,
        ),
      ),
      errorStyle: TextStyle(
        color: AppColors.redAlertColor,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    ),
    buttonTheme: ButtonThemeData(
      height: 46,
      buttonColor: AppColors.primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}
