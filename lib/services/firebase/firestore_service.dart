import 'package:cloud_firestore/cloud_firestore.dart';

/// Thin Firestore accessor. Repository implementations use this for I/O.
abstract final class FirestoreService {
  static FirebaseFirestore get instance => FirebaseFirestore.instance;

  /// All tenant-scoped reads/writes should include [companyId] in the path.
  static CollectionReference<Map<String, dynamic>> collection(String path) {
    return instance.collection(path);
  }

  static DocumentReference<Map<String, dynamic>> doc(String path) {
    return instance.doc(path);
  }
}
