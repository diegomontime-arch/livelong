import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/models/company.dart';

abstract interface class CompanyRepository {
  Future<Result<Company>> getById(String companyId);

  Future<Result<Company>> create(Company company);

  Future<Result<void>> update(Company company);
}
