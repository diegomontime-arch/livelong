import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hitlook/core/constants/firestore_paths.dart';
import 'package:hitlook/core/errors/app_exception.dart';
import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/firebase/firestore_mappers.dart';
import 'package:hitlook/data/models/company.dart';
import 'package:hitlook/data/repositories/company_repository.dart';
import 'package:hitlook/services/firebase/firestore_service.dart';

class FirebaseCompanyRepository implements CompanyRepository {
  @override
  Future<Result<Company>> getById(String companyId) {
    return FirestoreMappers.guard(() async {
      final snap =
          await FirestoreService.doc(FirestorePaths.company(companyId)).get();
      if (!snap.exists || snap.data() == null) {
        throw const NotFoundException('Company not found');
      }
      return _fromSnapshot(snap.id, snap.data()!);
    });
  }

  @override
  Future<Result<Company>> create(Company company) {
    return FirestoreMappers.guard(() async {
      final ref = company.id.isEmpty
          ? FirestoreService.collection(FirestorePaths.companies).doc()
          : FirestoreService.doc(FirestorePaths.company(company.id));

      await ref.set(
        FirestoreMappers.withCreatedTimestamps(company.toMap()),
      );

      final saved = await ref.get();
      return _fromSnapshot(saved.id, saved.data() ?? company.toMap());
    });
  }

  @override
  Future<Result<void>> update(Company company) {
    return FirestoreMappers.guard(() async {
      await FirestoreService.doc(FirestorePaths.company(company.id)).set(
        FirestoreMappers.withTimestamps(company.toMap()),
        SetOptions(merge: true),
      );
    });
  }

  Company _fromSnapshot(String id, Map<String, dynamic> data) {
    return Company(
      id: id,
      tenantId: data['tenantId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      plan: CompanyPlan.fromString(data['plan'] as String?),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: FirestoreMappers.timestampFrom(data['createdAt']),
    );
  }
}
