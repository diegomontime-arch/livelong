import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:hitlook/core/constants/firestore_paths.dart';
import 'package:hitlook/core/errors/app_exception.dart';
import 'package:hitlook/core/errors/failure.dart';
import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/firebase/firestore_mappers.dart';
import 'package:hitlook/data/models/seller.dart';
import 'package:hitlook/data/models/user.dart';
import 'package:hitlook/data/repositories/auth_repository.dart';
import 'package:hitlook/services/firebase/auth_service.dart';
import 'package:hitlook/services/firebase/firestore_service.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth}) : _auth = auth ?? AuthService.instance;

  final FirebaseAuth _auth;

  @override
  Stream<bool> get authStateChanges =>
      _auth.authStateChanges().map((user) => user != null);

  @override
  bool get isSignedIn => _auth.currentUser != null;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  Future<Result<void>> signInWithEmail({
    required String email,
    required String password,
  }) {
    return FirestoreMappers.guard(() async {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    });
  }

  @override
  Future<Result<void>> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return FirestoreMappers.guard(() async {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid == null) return;

      await FirestoreService.doc(FirestorePaths.user(uid)).set(
        FirestoreMappers.withCreatedTimestamps({
          'email': email.trim(),
          'role': UserRole.seller.name,
        }),
        SetOptions(merge: true),
      );
    });
  }

  @override
  Future<Result<void>> signOut() {
    return FirestoreMappers.guard(_auth.signOut);
  }

  @override
  Future<Result<Seller>> linkCurrentUserToSeller({
    required String companyId,
    required String sellerId,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      return const Error(AuthFailure('Not signed in'));
    }

    return FirestoreMappers.guard(() async {
      final sellerRef =
          FirestoreService.doc(FirestorePaths.companySeller(companyId, sellerId));
      final sellerSnap = await sellerRef.get();
      if (!sellerSnap.exists || sellerSnap.data() == null) {
        throw const NotFoundException('Seller not found');
      }

      await sellerRef.set(
        FirestoreMappers.withTimestamps({'userId': uid}),
        SetOptions(merge: true),
      );

      await FirestoreService.doc(FirestorePaths.user(uid)).set(
        FirestoreMappers.withTimestamps({
          'companyId': companyId,
          'sellerId': sellerId,
          'role': UserRole.seller.name,
        }),
        SetOptions(merge: true),
      );

      final data = sellerSnap.data()!;
      return Seller.fromMap(sellerId, {
        ...data,
        'companyId': companyId,
        'userId': uid,
      });
    });
  }
}
