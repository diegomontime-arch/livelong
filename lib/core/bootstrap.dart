import 'dart:async';
import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hitlook/services/firebase/firebase_options.dart';

/// Initializes platform services before [runApp].
///
/// Order matters:
/// 1. Bind the Flutter framework.
/// 2. Initialize Firebase Core.
/// 3. Wire crash reporting BEFORE any other code can throw.
/// 4. Activate Analytics (collection enabled by default in release).
/// 5. Apply the dark-only system overlay style.
///
/// See planning/PRODUCTION.md §G.2 and §G.3.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ─── Crashlytics (mobile only — not supported on Flutter Web) ───
  if (!kIsWeb) {
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);

    FlutterError.onError =
        FirebaseCrashlytics.instance.recordFlutterFatalError;

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // ─── Analytics ─────────────────────────────────────────────────
  // Default to enabled in release; the user can later opt out via UI when
  // a consent flow is added (see planning/LEGAL.md §3 — CCPA disclosure).
  try {
    await FirebaseAnalytics.instance
        .setAnalyticsCollectionEnabled(!kDebugMode);
  } catch (_) {
    // Web builds can run without analytics bindings; do not block startup.
  }

  // ─── System UI ─────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
}
