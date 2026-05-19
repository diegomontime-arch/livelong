/// App-wide configuration (environment, defaults).
abstract final class AppConfig {
  static const appName = 'HitLook';
  static const defaultLocale = 'en';

  /// Default tenant when none is resolved from host or route.
  static const defaultTenantId = 'm4life';

  /// Cloud Function / hosting proxy for Anthropic (no API keys in the client).
  static const anthropicProxyUrl =
      'https://hitlook-app.web.app/api/anthropic/v1/messages';

  /// Base URL for seller public links shown in admin dashboard.
  static const publicWebBaseUrl = 'https://hitlook-app.web.app';
}
