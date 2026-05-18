import 'package:firebase_storage/firebase_storage.dart';

/// Thin Firebase Storage accessor (seller photos, assets).
abstract final class StorageService {
  static FirebaseStorage get instance => FirebaseStorage.instance;

  static Reference ref(String path) => instance.ref(path);
}
