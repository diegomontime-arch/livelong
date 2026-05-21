/// Anthropic API proxy via Cloudflare Worker (see `cloudflare/`).
class AnaProxyConfig {
  static const String workerBase = 'https://hitlook-ana-proxy.hitlook.workers.dev';

  /// No API key in the app — the Worker adds `x-api-key` server-side.
  static const String messagesUrl = '$workerBase/v1/messages';

  static const String model = 'claude-sonnet-4-6';
}
