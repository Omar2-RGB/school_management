import 'package:flutter/material.dart';
import 'app_colors.dart';

class ThemeProvider extends ChangeNotifier {
  // لا حاجة لاستخدام const مع Colors.grey.shade300 في هذه الحالة
  static final lightTheme = ThemeData.light().copyWith(
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
    ),
    scaffoldBackgroundColor: Colors.grey.shade100,
    cardColor: Colors.white,
    // ...
  );

  static final darkTheme = ThemeData.dark().copyWith(
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
    ),
    scaffoldBackgroundColor: AppColors.background,
    cardColor: AppColors.cardColor,
    // ...
  );

  // إذا كنت تستخدم ChangeNotifierProvider، تأكد من إضافته في pubspec.yaml
  // لكننا الآن نستخدمه بدون Provider
}