import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/models/seller.dart';

/// Authentication and session boundaries for sellers.
abstract interface class AuthRepository {
  Stream<bool> get authStateChanges;

  bool get isSignedIn;

  String? get currentUserId;

  Future<Result<void>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Result<void>> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<Result<void>> signOut();

  /// Links the Firebase user to a [Seller] profile after onboarding.
  Future<Result<Seller>> linkCurrentUserToSeller({
    required String companyId,
    required String sellerId,
  });
}
