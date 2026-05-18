import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/models/tenant.dart';

abstract interface class TenantRepository {
  Future<Result<Tenant>> getById(String tenantId);

  Future<Result<Tenant>> resolveFromHost(String host);
}
