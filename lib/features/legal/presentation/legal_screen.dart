import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:hitlook/core/theme/app_colors.dart';

/// Tipo de documento legal renderizado pela [LegalScreen].
enum LegalDocument { privacy, terms }

/// In-app viewer for the public privacy policy and terms of use.
///
/// Apple Guideline 5.1.1 requires that any app collecting personal
/// information links to its Privacy Policy from inside the app. Rather
/// than re-translating the HTML in Dart, we render the published
/// `/privacy.html` / `/terms.html` (see `web/`) inside a WebView so the
/// single source of truth lives at `hitlook-app.web.app`.
class LegalScreen extends StatefulWidget {
  const LegalScreen({
    super.key,
    required this.document,
    this.lang = 'en',
  });

  final LegalDocument document;

  /// `en`, `pt`, or `es`. Anything else falls back to `en`.
  final String lang;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _hasError = false;

  static const _hostBase = 'https://hitlook-app.web.app';

  String get _url {
    final lang = switch (widget.lang) {
      'pt' || 'pt-BR' || 'pt-br' => 'pt',
      'es' => 'es',
      _ => 'en',
    };
    final base = switch (widget.document) {
      LegalDocument.privacy => 'privacy',
      LegalDocument.terms => 'terms',
    };
    return lang == 'en'
        ? '$_hostBase/$base.html'
        : '$_hostBase/$base.$lang.html';
  }

  String get _title => switch ((widget.document, widget.lang)) {
        (LegalDocument.privacy, 'pt' || 'pt-BR' || 'pt-br') => 'Privacidade',
        (LegalDocument.privacy, 'es') => 'Privacidad',
        (LegalDocument.privacy, _) => 'Privacy',
        (LegalDocument.terms, 'pt' || 'pt-BR' || 'pt-br') => 'Termos',
        (LegalDocument.terms, 'es') => 'Términos',
        (LegalDocument.terms, _) => 'Terms',
      };

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() {
              _loading = false;
              _hasError = true;
            });
          },
          // Block deep navigation away from the public legal pages.
          onNavigationRequest: (request) {
            final allowed = request.url.startsWith(_hostBase);
            return allowed
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(_url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: Text(
          _title,
          style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gold),
      ),
      body: Stack(
        children: [
          if (!_hasError) WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          if (_hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 48, color: AppColors.goldDim),
                    const SizedBox(height: 12),
                    Text(
                      _errorText(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.whiteWarm),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, color: AppColors.gold),
                      label: Text(_retryText(), style: const TextStyle(color: AppColors.gold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.gold),
                      ),
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _hasError = false;
                        });
                        _controller.loadRequest(Uri.parse(_url));
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _errorText() {
    switch (widget.lang) {
      case 'pt':
      case 'pt-BR':
      case 'pt-br':
        return 'Não foi possível carregar o documento.\nVerifique sua conexão.';
      case 'es':
        return 'No fue posible cargar el documento.\nVerifica tu conexión.';
      default:
        return 'Could not load the document.\nCheck your connection.';
    }
  }

  String _retryText() {
    switch (widget.lang) {
      case 'pt':
      case 'pt-BR':
      case 'pt-br':
        return 'Tentar novamente';
      case 'es':
        return 'Reintentar';
      default:
        return 'Retry';
    }
  }
}
