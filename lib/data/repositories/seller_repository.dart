import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/models/seller.dart';

abstract interface class SellerRepository {
  Future<Result<Seller>> getById({
    required String companyId,
    required String sellerId,
  });

  Future<Result<Seller>> getBySlug(String slug);

  Stream<List<Seller>> watchByCompany(String companyId);

  Future<Result<Seller>> upsert(Seller seller);
}
