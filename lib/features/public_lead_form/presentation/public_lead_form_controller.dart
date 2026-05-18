import 'package:flutter/foundation.dart';

import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/models/lead.dart';
import 'package:hitlook/data/models/seller.dart';
import 'package:hitlook/data/repositories/lead_repository.dart';
import 'package:hitlook/data/repositories/seller_repository.dart';

/// Public prospect flow: resolve seller by slug, then submit a new lead.
///
/// No auth required. Does not use [TenantScope]; company/seller come from
/// the loaded [Seller] profile.
enum PublicLeadFormPhase {
  initial,
  loadingSeller,
  ready,
  submitting,
  submitted,
  error,
}

class PublicLeadFormController extends ChangeNotifier {
  PublicLeadFormController({
    required SellerRepository sellerRepository,
    required LeadRepository leadRepository,
  })  : _sellerRepository = sellerRepository,
        _leadRepository = leadRepository;

  final SellerRepository _sellerRepository;
  final LeadRepository _leadRepository;

  PublicLeadFormPhase _phase = PublicLeadFormPhase.initial;
  Seller? _seller;
  String? _errorMessage;
  Lead? _submittedLead;

  PublicLeadFormPhase get phase => _phase;
  Seller? get seller => _seller;
  String? get errorMessage => _errorMessage;
  Lead? get submittedLead => _submittedLead;
  bool get isReady => _phase == PublicLeadFormPhase.ready;

  Future<void> loadSeller(String slug) async {
    _phase = PublicLeadFormPhase.loadingSeller;
    _errorMessage = null;
    notifyListeners();

    final result = await _sellerRepository.getBySlug(slug);
    switch (result) {
      case Success(value: final profile):
        _seller = profile;
        _phase = PublicLeadFormPhase.ready;
      case Error(failure: final f):
        _seller = null;
        _errorMessage = f.message;
        _phase = PublicLeadFormPhase.error;
    }
    notifyListeners();
  }

  Future<void> submitLead({
    required String locale,
    required Map<String, dynamic> answers,
    String? prospectName,
    String? prospectPhone,
    int? score,
    String? recommendedPlan,
  }) async {
    final seller = _seller;
    if (seller == null) {
      _errorMessage = 'Seller not loaded';
      _phase = PublicLeadFormPhase.error;
      notifyListeners();
      return;
    }

    _phase = PublicLeadFormPhase.submitting;
    _errorMessage = null;
    notifyListeners();

    final draft = Lead(
      id: '',
      companyId: seller.companyId,
      sellerId: seller.id,
      status: LeadStatus.newLead,
      locale: locale,
      answers: answers,
      prospectName: prospectName,
      prospectPhone: prospectPhone,
      score: score,
      recommendedPlan: recommendedPlan,
      createdAt: DateTime.now(),
    );

    final result = await _leadRepository.create(draft);
    switch (result) {
      case Success(value: final lead):
        _submittedLead = lead;
        _phase = PublicLeadFormPhase.submitted;
      case Error(failure: final f):
        _errorMessage = f.message;
        _phase = PublicLeadFormPhase.error;
    }
    notifyListeners();
  }

  void reset() {
    _phase = PublicLeadFormPhase.initial;
    _seller = null;
    _submittedLead = null;
    _errorMessage = null;
    notifyListeners();
  }
}
