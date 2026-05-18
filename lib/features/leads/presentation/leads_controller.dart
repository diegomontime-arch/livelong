import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:hitlook/core/tenant/tenant_scope.dart';
import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/models/lead.dart';
import 'package:hitlook/data/repositories/lead_repository.dart';

/// Lists and updates leads for the signed-in seller within the active company.
class LeadsController extends ChangeNotifier {
  LeadsController({
    required LeadRepository leadRepository,
    required TenantScope tenantScope,
  })  : _leadRepository = leadRepository,
        _tenantScope = tenantScope;

  final LeadRepository _leadRepository;
  final TenantScope _tenantScope;

  StreamSubscription<List<Lead>>? _leadsSubscription;

  List<Lead> _leads = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Lead> get leads => _leads;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isEmpty => _leads.isEmpty;

  void startWatching() {
    final companyId = _tenantScope.companyId;
    final sellerId = _tenantScope.sellerId;
    if (companyId == null || sellerId == null) {
      _errorMessage = 'Seller session is not ready';
      notifyListeners();
      return;
    }

    _setLoading(true);
    _leadsSubscription?.cancel();
    _leadsSubscription = _leadRepository
        .watchBySeller(companyId: companyId, sellerId: sellerId)
        .listen(
      (leads) {
        _leads = leads;
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
      },
      onError: (Object error) {
        _errorMessage = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> updateStatus({
    required String leadId,
    required LeadStatus status,
  }) async {
    final companyId = _tenantScope.requireCompanyId();
    final result = await _leadRepository.updateStatus(
      companyId: companyId,
      leadId: leadId,
      status: status,
    );
    _errorMessage = switch (result) {
      Success() => null,
      Error(failure: final f) => f.message,
    };
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _leadsSubscription?.cancel();
    super.dispose();
  }
}
