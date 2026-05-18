import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/models/lead.dart';

abstract interface class LeadRepository {
  Future<Result<Lead>> getById({
    required String companyId,
    required String leadId,
  });

  Stream<List<Lead>> watchByCompany(String companyId);

  Stream<List<Lead>> watchBySeller({
    required String companyId,
    required String sellerId,
  });

  Future<Result<Lead>> create(Lead lead);

  Future<Result<void>> updateStatus({
    required String companyId,
    required String leadId,
    required LeadStatus status,
  });
}
