import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hitlook/core/utils/whatsapp_launcher_stub.dart'
    if (dart.library.html) 'package:hitlook/core/utils/whatsapp_launcher_web.dart'
    as whatsapp_launcher;

/// Default consultant WhatsApp (Renan) when agent profile has no number.
const kDefaultConsultantWhatsApp = '17869738628';

/// Normalizes a phone number for wa.me (digits only; US 10-digit → prepend 1).
String normalizeWhatsAppNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  if (digits.length == 10) return '1$digits';
  return digits;
}

/// Builds the wa.me URI (https://wa.me/NUM?text=...).
Uri buildWhatsAppUri({required String phone, required String message}) {
  final numero = normalizeWhatsAppNumber(phone);
  if (numero.isEmpty) {
    throw ArgumentError('Invalid WhatsApp phone: $phone');
  }
  return Uri.parse(
    'https://wa.me/$numero?text=${Uri.encodeComponent(message)}',
  );
}

/// Opens WhatsApp with a pre-filled message.
Future<bool> openWhatsApp({
  required String phone,
  required String message,
}) async {
  final uri = buildWhatsAppUri(phone: phone, message: message);
  debugPrint('[WhatsApp] abrindo: $uri');

  if (kIsWeb) {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (launched) {
      debugPrint('[WhatsApp] launchUrl OK (externalApplication)');
      return true;
    }

    debugPrint('[WhatsApp] launchUrl false — fallback window.open');
    return whatsapp_launcher.openWhatsAppInBrowser(uri.toString());
  }

  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  debugPrint('[WhatsApp] canLaunchUrl=false para $uri');
  return false;
}

String buildLeadWhatsAppMessage({
  required String lang,
  required int score,
}) {
  if (lang == 'es') {
    return '¡Hola! Acabo de hacer el diagnóstico de protección familiar y '
        'recibí un score de $score%. Me gustaría saber más sobre las '
        'opciones disponibles.';
  }
  if (lang == 'en') {
    return 'Hi! I just completed the family protection diagnosis and '
        'received a score of $score%. I\'d like to know more about the '
        'available options for my family.';
  }
  return 'Olá! Acabei de fazer o diagnóstico de proteção familiar e recebi '
      'um score de $score%. Gostaria de saber mais sobre as opções '
      'disponíveis para minha família.';
}
