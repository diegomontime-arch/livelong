import 'package:flutter/foundation.dart';

import 'package:hitlook/core/config/tenant_config.dart';
import 'package:hitlook/core/errors/app_exception.dart';

/// Holds the active tenant and company for the current session or route.
///
/// Set when the user logs in or when a public lead form is opened.
class TenantScope extends ChangeNotifier {
  TenantConfig? _tenant;
  String? _companyId;
  String? _sellerId;

  TenantConfig? get tenant => _tenant;
  String? get companyId => _companyId;
  String? get sellerId => _sellerId;

  bool get hasTenant => _tenant != null;
  bool get hasCompany => _companyId != null;

  void setTenant(TenantConfig tenant) {
    _tenant = tenant;
    notifyListeners();
  }

  void setCompany(String companyId) {
    _companyId = companyId;
    notifyListeners();
  }

  void setSeller(String sellerId) {
    _sellerId = sellerId;
    notifyListeners();
  }

  void clear() {
    _tenant = null;
    _companyId = null;
    _sellerId = null;
    notifyListeners();
  }

  String requireCompanyId() {
    final id = _companyId;
    if (id == null) throw const CompanyScopeException();
    return id;
  }

  TenantConfig requireTenant() {
    final t = _tenant;
    if (t == null) throw const TenantScopeException();
    return t;
  }
}
