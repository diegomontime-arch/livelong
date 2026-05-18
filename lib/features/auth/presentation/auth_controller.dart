import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:hitlook/core/tenant/tenant_scope.dart';
import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/repositories/auth_repository.dart';

/// Coordinates seller authentication. UI binds to this; Firebase stays in repositories.
class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository authRepository,
    required TenantScope tenantScope,
  })  : _authRepository = authRepository,
        _tenantScope = tenantScope;

  final AuthRepository _authRepository;
  final TenantScope _tenantScope;

  StreamSubscription<bool>? _authSubscription;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isSignedIn = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSignedIn => _isSignedIn;
  String? get currentUserId => _authRepository.currentUserId;

  /// Call once when the auth feature is mounted (e.g. from a parent widget).
  void start() {
    _isSignedIn = _authRepository.isSignedIn;
    _authSubscription ??= _authRepository.authStateChanges.listen((signedIn) {
      _isSignedIn = signedIn;
      if (!signedIn) _tenantScope.clear();
      notifyListeners();
    });
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _run(() => _authRepository.signInWithEmail(
          email: email,
          password: password,
        ));
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    await _run(() => _authRepository.signUpWithEmail(
          email: email,
          password: password,
        ));
  }

  Future<void> signOut() async {
    await _run(_authRepository.signOut);
  }

  Future<void> _run(Future<Result<void>> Function() action) async {
    _setLoading(true);
    final result = await action();
    _errorMessage = _messageFrom(result);
    _setLoading(false);
  }

  String? _messageFrom(Result<void> result) => switch (result) {
        Success() => null,
        Error(failure: final f) => f.message,
      };

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
