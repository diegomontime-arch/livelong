import 'package:hitlook/core/config/app_config.dart';
import 'package:hitlook/core/constants/firestore_paths.dart';
import 'package:hitlook/core/errors/app_exception.dart';
import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/firebase/firestore_mappers.dart';
import 'package:hitlook/data/models/tenant.dart';
import 'package:hitlook/data/repositories/tenant_repository.dart';
import 'package:hitlook/services/firebase/firestore_service.dart';

class FirebaseTenantRepository implements TenantRepository {
  @override
  Future<Result<Tenant>> getById(String tenantId) {
    return FirestoreMappers.guard(() async {
      final snap =
          await FirestoreService.doc(FirestorePaths.tenant(tenantId)).get();
      if (!snap.exists || snap.data() == null) {
        throw const NotFoundException('Tenant not found');
      }
      return Tenant.fromMap(snap.id, snap.data()!);
    });
  }

  @override
  Future<Result<Tenant>> resolveFromHost(String host) {
    final tenantId = _tenantIdFromHost(host);
    return getById(tenantId);
  }

  String _tenantIdFromHost(String host) {
    final normalized = host.toLowerCase();
    if (normalized.contains('m4life')) return 'm4life';
    if (normalized.contains('portobello')) return 'portobello';
    return AppConfig.defaultTenantId;
  }
}
