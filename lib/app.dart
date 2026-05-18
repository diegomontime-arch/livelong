import 'package:flutter/material.dart';

import 'package:hitlook/core/config/app_config.dart';
import 'package:hitlook/core/routing/app_router.dart';
import 'package:hitlook/core/theme/app_theme.dart';

class HitLookApp extends StatelessWidget {
  const HitLookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
