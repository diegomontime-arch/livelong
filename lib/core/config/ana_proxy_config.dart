/// Anthropic API proxy via Cloudflare Worker (see `cloudflare/`).
///
/// After `wrangler deploy`, set [messagesUrl] to:
/// `https://hitlook-ana-proxy.<your-subdomain>.workers.dev/v1/messages`
class AnaProxyConfig {
  /// Update this URL after Cloudflare deploy (no API key in the app).
  /// Replace `<subdomain>` with your workers.dev host from `wrangler deploy`.
  static const String messagesUrl =
      'https://hitlook-ana-proxy.<subdomain>.workers.dev/v1/messages';
}
