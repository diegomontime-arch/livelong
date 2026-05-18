import 'package:firebase_auth/firebase_auth.dart';

/// Thin Firebase Auth accessor.
abstract final class AuthService {
  static FirebaseAuth get instance => FirebaseAuth.instance;

  static User? get currentUser => instance.currentUser;

  static Stream<User?> get authStateChanges => instance.authStateChanges();
}
