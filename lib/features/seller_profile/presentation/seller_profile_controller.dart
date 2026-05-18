import 'package:flutter/foundation.dart';

import 'package:hitlook/core/tenant/tenant_scope.dart';
import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/models/seller.dart';
import 'package:hitlook/data/repositories/seller_repository.dart';

/// Loads and saves the signed-in seller profile for the active company.
class SellerProfileController extends ChangeNotifier {
  SellerProfileController({
    required SellerRepository sellerRepository,
    required TenantScope tenantScope,
  })  : _sellerRepository = sellerRepository,
        _tenantScope = tenantScope;

  final SellerRepository _sellerRepository;
  final TenantScope _tenantScope;

  Seller? _seller;
  bool _isLoading = false;
  String? _errorMessage;

  Seller? get seller => _seller;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasProfile => _seller != null;

  Future<void> load() async {
    final companyId = _tenantScope.companyId;
    final sellerId = _tenantScope.sellerId;
    if (companyId == null || sellerId == null) {
      _errorMessage = 'Seller session is not ready';
      notifyListeners();
      return;
    }

    _setLoading(true);
    final result = await _sellerRepository.getById(
      companyId: companyId,
      sellerId: sellerId,
    );
    switch (result) {
      case Success(value: final profile):
        _seller = profile;
        _errorMessage = null;
      case Error(failure: final f):
        _errorMessage = f.message;
    }
    _setLoading(false);
  }

  Future<void> save(Seller profile) async {
    _setLoading(true);
    final result = await _sellerRepository.upsert(profile);
    switch (result) {
      case Success(value: final saved):
        _seller = saved;
        _tenantScope.setSeller(saved.id);
        _errorMessage = null;
      case Error(failure: final f):
        _errorMessage = f.message;
    }
    _setLoading(false);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
