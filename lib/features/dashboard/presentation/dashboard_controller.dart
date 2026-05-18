import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:hitlook/core/tenant/tenant_scope.dart';
import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/models/lead.dart';
import 'package:hitlook/data/models/seller.dart';
import 'package:hitlook/data/repositories/lead_repository.dart';
import 'package:hitlook/data/repositories/seller_repository.dart';

/// Aggregates seller context and recent leads for the home dashboard.
class DashboardController extends ChangeNotifier {
  DashboardController({
    required LeadRepository leadRepository,
    required SellerRepository sellerRepository,
    required TenantScope tenantScope,
  })  : _leadRepository = leadRepository,
        _sellerRepository = sellerRepository,
        _tenantScope = tenantScope;

  final LeadRepository _leadRepository;
  final SellerRepository _sellerRepository;
  final TenantScope _tenantScope;

  StreamSubscription<List<Lead>>? _leadsSubscription;

  Seller? _seller;
  List<Lead> _recentLeads = const [];
  bool _isLoading = false;
  String? _errorMessage;

  Seller? get seller => _seller;
  List<Lead> get recentLeads => _recentLeads;
  int get totalLeads => _recentLeads.length;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    final companyId = _tenantScope.companyId;
    final sellerId = _tenantScope.sellerId;
    if (companyId == null || sellerId == null) {
      _errorMessage = 'Seller session is not ready';
      notifyListeners();
      return;
    }

    _setLoading(true);
    await _loadSeller(companyId: companyId, sellerId: sellerId);
    _startWatchingLeads(companyId: companyId, sellerId: sellerId);
    _setLoading(false);
  }

  Future<void> _loadSeller({
    required String companyId,
    required String sellerId,
  }) async {
    final result = await _sellerRepository.getById(
      companyId: companyId,
      sellerId: sellerId,
    );
    switch (result) {
      case Success(value: final profile):
        _seller = profile;
      case Error(failure: final f):
        _errorMessage = f.message;
    }
  }

  void _startWatchingLeads({
    required String companyId,
    required String sellerId,
  }) {
    _leadsSubscription?.cancel();
    _leadsSubscription = _leadRepository
        .watchBySeller(companyId: companyId, sellerId: sellerId)
        .listen(
      (leads) {
        _recentLeads = leads.take(5).toList();
        notifyListeners();
      },
      onError: (Object error) {
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
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
