import 'package:firebase_auth/firebase_auth.dart';
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

  /// Route after successful login. Never throws — sellers without `users/{uid}` go to dashboard.
  static Future<String> postLoginRoute() async {
    try {
      final session = await load();
      if (session?.isAdmin == true) return RoutePaths.admin;
    } catch (e, st) {
      debugPrint('[HitLook:AdminSession] postLoginRoute load failed: $e\n$st');
    }
    return RoutePaths.dashboard;
  }

  static Future<AdminSession?> load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final snap = await FirestoreService.doc(FirestorePaths.user(uid)).get();
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
