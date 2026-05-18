import 'package:flutter/material.dart';

import 'package:hitlook/core/theme/app_colors.dart';

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.black,
        fontFamily: 'Roboto',
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.black,
          primary: AppColors.accent,
        ),
      );
}
