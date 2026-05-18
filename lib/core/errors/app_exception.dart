/// Internal exceptions thrown by services and repositories.
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'AppException: $message${cause != null ? ' ($cause)' : ''}';
}

class TenantScopeException extends AppException {
  const TenantScopeException([super.message = 'Tenant scope is not set']);
}

class CompanyScopeException extends AppException {
  const CompanyScopeException([super.message = 'Company scope is not set']);
}

class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Resource not found']);
}
