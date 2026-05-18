import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hitlook/core/constants/firestore_paths.dart';
import 'package:hitlook/core/errors/app_exception.dart';
import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/firebase/firestore_mappers.dart';
import 'package:hitlook/data/models/user.dart';
import 'package:hitlook/data/repositories/user_repository.dart';
import 'package:hitlook/services/firebase/firestore_service.dart';

class FirebaseUserRepository implements UserRepository {
  @override
  Future<Result<AppUser>> getById(String userId) {
    return FirestoreMappers.guard(() async {
      final snap = await FirestoreService.doc(FirestorePaths.user(userId)).get();
      if (!snap.exists || snap.data() == null) {
        throw const NotFoundException('User not found');
      }
      return _fromSnapshot(snap.id, snap.data()!);
    });
  }

  @override
  Future<Result<AppUser>> upsert(AppUser user) {
    return FirestoreMappers.guard(() async {
      final ref = FirestoreService.doc(FirestorePaths.user(user.id));
      await ref.set(
        FirestoreMappers.withTimestamps(user.toMap()),
        SetOptions(merge: true),
      );
      final saved = await ref.get();
      return _fromSnapshot(saved.id, saved.data() ?? user.toMap());
    });
  }

  @override
  Future<Result<AppUser>> linkToSeller({
    required String userId,
    required String companyId,
    required String sellerId,
    String? tenantId,
  }) {
    return FirestoreMappers.guard(() async {
      final ref = FirestoreService.doc(FirestorePaths.user(userId));
      await ref.set(
        FirestoreMappers.withTimestamps({
          'companyId': companyId,
          'sellerId': sellerId,
          'tenantId': ?tenantId,
          'role': UserRole.seller.name,
        }),
        SetOptions(merge: true),
      );
      final saved = await ref.get();
      return _fromSnapshot(saved.id, saved.data() ?? {});
    });
  }

  AppUser _fromSnapshot(String id, Map<String, dynamic> data) {
    return AppUser.fromMap(id, data).copyWith(
      createdAt: FirestoreMappers.timestampFrom(data['createdAt']),
      updatedAt: FirestoreMappers.timestampFrom(data['updatedAt']),
    );
  }
}
