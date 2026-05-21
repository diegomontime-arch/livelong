import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_storage/firebase_storage.dart';

import 'package:hitlook/core/config/app_config.dart';
import 'package:hitlook/core/constants/firestore_paths.dart';
import 'package:hitlook/core/errors/failure.dart';
import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/models/seller.dart';
import 'package:hitlook/data/repositories/firebase/firebase_seller_repository.dart';
import 'package:hitlook/services/firebase/firestore_service.dart';

class CreateSellerService {
  CreateSellerService({
    FirebaseFunctions? functions,
    FirebaseSellerRepository? sellerRepo,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _sellerRepo = sellerRepo ?? FirebaseSellerRepository();

  final FirebaseFunctions _functions;
  final FirebaseSellerRepository _sellerRepo;

  Future<Result<Seller>> create({
    required String companyId,
    required String displayName,
    required String email,
    required String phone,
    required String slug,
    Uint8List? photoBytes,
    String? photoContentType,
  }) async {
    try {
      final callable = _functions.httpsCallable('createSellerAccount');
      final authResult = await callable.call<Map<String, dynamic>>({
        'email': email.trim(),
        'password': AppConfig.defaultSellerPassword,
        'displayName': displayName.trim(),
        'companyId': companyId,
      });

      final uid = authResult.data['uid'] as String?;
      if (uid == null || uid.isEmpty) {
        return const Error(UnknownFailure('Auth UID missing from createSellerAccount'));
      }

      var photoUrl = '';
      if (photoBytes != null && photoBytes.isNotEmpty) {
        final ref = FirebaseStorage.instance.ref().child('agents/$uid/photo');
        final task = await ref.putData(
          photoBytes,
          SettableMetadata(contentType: photoContentType ?? 'image/jpeg'),
        );
        photoUrl = await task.ref.getDownloadURL();
      }

      final seller = Seller(
        id: slug.trim(),
        companyId: companyId,
        displayName: displayName.trim(),
        slug: slug.trim(),
        email: email.trim(),
        phone: phone.trim(),
        photoUrl: photoUrl.isEmpty ? null : photoUrl,
        userId: uid,
        isActive: true,
      );

      final saved = await _sellerRepo.upsert(seller);
      if (saved is Error<Seller>) return saved;

      final ok = (saved as Success<Seller>).value;
      await _writeUserAndAgents(
        uid: uid,
        companyId: companyId,
        seller: ok,
        photoUrl: photoUrl,
        phone: phone.trim(),
      );

      return Success(ok);
    } on FirebaseFunctionsException catch (e) {
      return Error(UnknownFailure(e.message ?? 'Erro ao criar conta do agente'));
    } catch (e) {
      return Error(UnknownFailure(e.toString()));
    }
  }

  Future<void> _writeUserAndAgents({
    required String uid,
    required String companyId,
    required Seller seller,
    required String photoUrl,
    required String phone,
  }) async {
    final slug = seller.slug ?? seller.id;
    final batch = FirebaseFirestore.instance.batch();

    batch.set(
      FirestoreService.doc(FirestorePaths.user(uid)),
      {
        'email': seller.email,
        'role': 'seller',
        'companyId': companyId,
        'sellerId': seller.id,
        'displayName': seller.displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final agentPayload = {
      'nome': seller.displayName,
      'bio': seller.bio ?? '',
      'whatsapp': phone,
      'fotoUrl': photoUrl,
      'userId': uid,
      'slug': slug,
      'idioma': 'pt',
      'nicho': 'seguro',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    batch.set(
      FirebaseFirestore.instance.collection('agents').doc(uid),
      agentPayload,
      SetOptions(merge: true),
    );
    if (slug.isNotEmpty && slug != uid) {
      batch.set(
        FirebaseFirestore.instance.collection('agents').doc(slug),
        agentPayload,
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }
}
