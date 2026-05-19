import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hitlook/core/constants/firestore_paths.dart';
import 'package:hitlook/core/errors/app_exception.dart';
import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/firebase/firestore_mappers.dart';
import 'package:hitlook/data/models/lead.dart';
import 'package:hitlook/data/repositories/lead_repository.dart';
import 'package:hitlook/services/firebase/firestore_service.dart';

class FirebaseLeadRepository implements LeadRepository {
  CollectionReference<Map<String, dynamic>> _leads(String companyId) {
    return FirestoreService.collection(FirestorePaths.companyLeads(companyId));
  }

  @override
  Future<Result<Lead>> getById({
    required String companyId,
    required String leadId,
  }) {
    return FirestoreMappers.guard(() async {
      final snap =
          await FirestoreService.doc(FirestorePaths.companyLead(companyId, leadId))
              .get();
      if (!snap.exists || snap.data() == null) {
        throw const NotFoundException('Lead not found');
      }
      return _fromSnapshot(snap.id, snap.data()!, companyId);
    });
  }

  @override
  Stream<List<Lead>> watchByCompany(String companyId) {
    return _leads(companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _fromSnapshot(doc.id, doc.data(), companyId))
              .toList(),
        );
  }

  @override
  Stream<List<Lead>> watchBySeller({
    required String companyId,
    required String sellerId,
  }) {
    return _leads(companyId)
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _fromSnapshot(doc.id, doc.data(), companyId))
              .toList(),
        );
  }

  @override
  Future<Result<Lead>> create(Lead lead) {
    return FirestoreMappers.guard(() async {
      final ref = lead.id.isEmpty
          ? _leads(lead.companyId).doc()
          : FirestoreService.doc(
              FirestorePaths.companyLead(lead.companyId, lead.id),
            );

      final payload = {
        ...lead.toMap(),
        'companyId': lead.companyId,
        'sellerId': lead.sellerId,
        'status': _statusToFirestore(lead.status),
      };

      await ref.set(FirestoreMappers.withCreatedTimestamps(payload));
      final saved = await ref.get();
      return _fromSnapshot(saved.id, saved.data() ?? payload, lead.companyId);
    });
  }

  @override
  Future<Result<void>> updateStatus({
    required String companyId,
    required String leadId,
    required LeadStatus status,
  }) {
    return FirestoreMappers.guard(() async {
      await FirestoreService.doc(FirestorePaths.companyLead(companyId, leadId))
          .set(
        FirestoreMappers.withTimestamps({'status': _statusToFirestore(status)}),
        SetOptions(merge: true),
      );
    });
  }

  Lead _fromSnapshot(String id, Map<String, dynamic> data, String companyId) {
    final statusRaw = data['status'] as String?;
    return Lead.fromMap(id, {
      ...data,
      'companyId': data['companyId'] as String? ?? companyId,
      'status': _statusFromFirestore(statusRaw),
      'createdAt': FirestoreMappers.timestampFrom(data['createdAt']),
    });
  }

  static String _statusToFirestore(LeadStatus status) {
    return switch (status) {
      LeadStatus.newLead => 'new',
      LeadStatus.contacted => 'contacted',
      LeadStatus.followUp => 'follow_up',
      LeadStatus.closed => 'closed',
      LeadStatus.lost => 'lost',
    };
  }

  static String _statusFromFirestore(String? value) {
    return LeadStatus.fromString(value).name;
  }
}
