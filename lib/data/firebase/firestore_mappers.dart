import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:hitlook/core/errors/app_exception.dart';
import 'package:hitlook/core/errors/failure.dart';
import 'package:hitlook/core/utils/result.dart';

/// Shared Firestore ↔ domain conversions and error mapping.
abstract final class FirestoreMappers {
  static DateTime? timestampFrom(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static Map<String, dynamic> withTimestamps(Map<String, dynamic> data) {
    return {
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, dynamic> withCreatedTimestamps(Map<String, dynamic> data) {
    return {
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Future<Result<T>> guard<T>(Future<T> Function() run) async {
    try {
      return Success(await run());
    } on NotFoundException catch (e) {
      return Error(NotFoundFailure(e.message));
    } on FirebaseAuthException catch (e) {
      return Error(AuthFailure(e.message ?? 'Authentication failed'));
    } on FirebaseException catch (e) {
      if (e.code == 'not-found' || e.code == 'NOT_FOUND') {
        return Error(NotFoundFailure(e.message ?? 'Not found'));
      }
      if (e.code == 'permission-denied') {
        return Error(PermissionFailure(e.message ?? 'Permission denied'));
      }
      return Error(NetworkFailure(e.message ?? 'Firestore error'));
    } catch (e) {
      return Error(UnknownFailure(e.toString()));
    }
  }

  static Stream<T> guardStream<T>(Stream<T> stream) {
    return stream.handleError((Object _, StackTrace __) {
      throw UnknownFailure('Stream error');
    });
  }
}
