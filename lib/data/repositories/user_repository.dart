import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/models/user.dart';

abstract interface class UserRepository {
  Future<Result<AppUser>> getById(String userId);

  Future<Result<AppUser>> upsert(AppUser user);

  Future<Result<AppUser>> linkToSeller({
    required String userId,
    required String companyId,
    required String sellerId,
    String? tenantId,
  });
}
