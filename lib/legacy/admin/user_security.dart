import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// First-login password change for sellers created by admin.
abstract final class UserSecurity {
  static Future<bool> mustChangePassword() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!snap.exists || snap.data() == null) return false;
      final data = snap.data()!;
      if (data['role'] != 'seller') return false;
      return data['mustChangePassword'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearMustChangePassword(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'mustChangePassword': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
