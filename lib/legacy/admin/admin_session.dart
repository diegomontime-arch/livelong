import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'package:hitlook/core/constants/firestore_paths.dart';
import 'package:hitlook/core/constants/route_paths.dart';
import 'package:hitlook/data/models/user.dart';
import 'package:hitlook/services/firebase/firestore_service.dart';

/// Loads the signed-in user's company scope for admin screens.
class AdminSession {
  AdminSession({
    required this.userId,
    required this.companyId,
    required this.role,
    this.email,
    this.displayName,
  });

  final String userId;
  final String companyId;
  final UserRole role;
  final String? email;
  final String? displayName;

  bool get isAdmin => role == UserRole.admin;

  static const _loadTimeout = Duration(seconds: 8);

  /// Route after successful login. Never throws.
  /// Vendedores sem `users/{uid}` vão para [RoutePaths.dashboard].
  static Future<String> postLoginRoute() async {
    final session = await load();
    if (session?.isAdmin == true) {
      debugPrint('[HitLook:AdminSession] postLoginRoute → admin (${session!.companyId})');
      return RoutePaths.admin;
    }
    if (session == null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      debugPrint(
        '[HitLook:AdminSession] postLoginRoute → dashboard (no users/$uid doc or timeout)',
      );
    }
    return RoutePaths.dashboard;
  }

  /// SaaS profile in `users/{uid}`. Missing doc is normal for legacy sellers.
  static Future<AdminSession?> load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('[HitLook:AdminSession] load: no Firebase user');
      return null;
    }

    try {
      final snap = await FirestoreService.doc(FirestorePaths.user(uid))
          .get()
          .timeout(_loadTimeout);

      if (!snap.exists || snap.data() == null) {
        debugPrint('[HitLook:AdminSession] load: users/$uid does not exist');
        return null;
      }

      final data = snap.data()!;
      final companyId = data['companyId'] as String?;
      if (companyId == null || companyId.isEmpty) {
        debugPrint('[HitLook:AdminSession] load: users/$uid missing companyId');
        return null;
      }

      final role = UserRole.fromString(data['role'] as String?);
      debugPrint('[HitLook:AdminSession] load OK role=${role.name} company=$companyId');

      // ── Crashlytics context (planning/CHECKLIST.md P5) ──────────────
      // setUserIdentifier accepts an opaque string; Firebase UID is fine
      // and is not considered PII when disconnected from the email.
      try {
        FirebaseCrashlytics.instance.setUserIdentifier(uid);
        FirebaseCrashlytics.instance.setCustomKey('role', role.name);
        FirebaseCrashlytics.instance.setCustomKey('companyId', companyId);
      } catch (_) {
        // Crashlytics may be uninitialized in tests; ignore.
      }

      return AdminSession(
        userId: uid,
        companyId: companyId,
        role: role,
        email: data['email'] as String?,
        displayName: data['displayName'] as String?,
      );
    } on TimeoutException {
      debugPrint('[HitLook:AdminSession] load TIMEOUT users/$uid → treat as legacy seller');
      return null;
    } on FirebaseException catch (e) {
      debugPrint('[HitLook:AdminSession] load Firestore ${e.code}: ${e.message}');
      return null;
    } catch (e, st) {
      debugPrint('[HitLook:AdminSession] load unexpected: $e\n$st');
      return null;
    }
  }

  static Stream<AdminSession?> watch() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return FirestoreService.doc(FirestorePaths.user(uid)).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      final data = snap.data()!;
      final companyId = data['companyId'] as String?;
      if (companyId == null || companyId.isEmpty) return null;
      return AdminSession(
        userId: uid,
        companyId: companyId,
        role: UserRole.fromString(data['role'] as String?),
        email: data['email'] as String?,
        displayName: data['displayName'] as String?,
      );
    });
  }
}
