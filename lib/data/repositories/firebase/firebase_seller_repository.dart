import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hitlook/core/constants/firestore_paths.dart';
import 'package:hitlook/core/errors/app_exception.dart';
import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/firebase/firestore_mappers.dart';
import 'package:hitlook/data/models/seller.dart';
import 'package:hitlook/data/repositories/seller_repository.dart';
import 'package:hitlook/services/firebase/firestore_service.dart';

class FirebaseSellerRepository implements SellerRepository {
  @override
  Future<Result<Seller>> getById({
    required String companyId,
    required String sellerId,
  }) {
    return FirestoreMappers.guard(() async {
      final snap = await FirestoreService.doc(
        FirestorePaths.companySeller(companyId, sellerId),
      ).get();
      if (!snap.exists || snap.data() == null) {
        throw const NotFoundException('Seller not found');
      }
      return _fromSnapshot(snap.id, snap.data()!, companyId);
    });
  }

  @override
  Future<Result<Seller>> getBySlug(String slug) {
    return FirestoreMappers.guard(() async {
      final slugSnap =
          await FirestoreService.doc(FirestorePaths.sellerSlug(slug)).get();
      if (!slugSnap.exists || slugSnap.data() == null) {
        throw const NotFoundException('Seller slug not found');
      }
      final data = slugSnap.data()!;
      final companyId = data['companyId'] as String?;
      final sellerId = data['sellerId'] as String?;
      if (companyId == null || sellerId == null) {
        throw const NotFoundException('Seller slug not found');
      }
      final sellerResult = await getById(
        companyId: companyId,
        sellerId: sellerId,
      );
      if (sellerResult is Error<Seller>) {
        throw NotFoundException(sellerResult.failure.message);
      }
      return (sellerResult as Success<Seller>).value;
    });
  }

  @override
  Stream<List<Seller>> watchByCompany(String companyId) {
    return FirestoreService.collection(FirestorePaths.companySellers(companyId))
        .orderBy('displayName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _fromSnapshot(doc.id, doc.data(), companyId))
              .toList(),
        );
  }

  @override
  Future<Result<Seller>> upsert(Seller seller) {
    return FirestoreMappers.guard(() async {
      final ref = seller.id.isEmpty
          ? FirestoreService.collection(
              FirestorePaths.companySellers(seller.companyId),
            ).doc()
          : FirestoreService.doc(
              FirestorePaths.companySeller(seller.companyId, seller.id),
            );

      final payload = {
        ...seller.toMap(),
        'companyId': seller.companyId,
      };

      await ref.set(
        FirestoreMappers.withTimestamps(payload),
        SetOptions(merge: true),
      );

      if (seller.slug != null && seller.slug!.isNotEmpty) {
        await _upsertSlugIndex(
          slug: seller.slug!,
          companyId: seller.companyId,
          sellerId: ref.id,
        );
      }

      final saved = await ref.get();
      return _fromSnapshot(saved.id, saved.data() ?? payload, seller.companyId);
    });
  }

  Future<void> _upsertSlugIndex({
    required String slug,
    required String companyId,
    required String sellerId,
  }) async {
    await FirestoreService.doc(FirestorePaths.sellerSlug(slug)).set({
      'companyId': companyId,
      'sellerId': sellerId,
      'slug': slug,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Seller _fromSnapshot(
    String id,
    Map<String, dynamic> data,
    String companyId,
  ) {
    return Seller.fromMap(id, {
      ...data,
      'companyId': data['companyId'] as String? ?? companyId,
    });
  }
}
