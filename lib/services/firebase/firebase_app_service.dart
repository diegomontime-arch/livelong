import 'package:firebase_core/firebase_core.dart';

import 'package:hitlook/services/firebase/firebase_options.dart';

/// Firebase app initialization wrapper.
abstract final class FirebaseAppService {
  static Future<FirebaseApp> initialize() {
    return Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
