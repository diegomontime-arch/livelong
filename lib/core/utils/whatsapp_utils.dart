import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hitlook/core/utils/whatsapp_launcher_stub.dart'
    if (dart.library.html) 'package:hitlook/core/utils/whatsapp_launcher_web.dart'
    as whatsapp_launcher;

/// Default consultant WhatsApp (Renan) when agent profile has no number.
const kDefaultConsultantWhatsApp = '17869738628';

/// Formats phone for wa.me — always includes country code.
String formatWhatsAppNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return kDefaultConsultantWhatsApp;

  // Já tem código EUA (11+ dígitos começando com 1)
  if (digits.length >= 11 && digits.startsWith('1')) return digits;

  // 10 dígitos → EUA
  if (digits.length == 10) return '1$digits';

  // 11 dígitos começando com 0 → Brasil (remove 0, adiciona 55)
  if (digits.length == 11 && digits.startsWith('0')) {
    return '55${digits.substring(1)}';
  }

  // 11 dígitos sem código → Brasil
  if (digits.length == 11) return '55$digits';

  return digits;
}

/// Returns formatted number or empty if [raw] is blank (for validation).
String normalizeWhatsAppNumber(String raw) {
  if (raw.trim().isEmpty) return '';
  return formatWhatsAppNumber(raw);
}

/// Builds the wa.me URI (https://wa.me/NUM?text=...).
Uri buildWhatsAppUri({required String phone, required String message}) {
  final numero = phone.trim().isEmpty
      ? kDefaultConsultantWhatsApp
      : formatWhatsAppNumber(phone);
  return Uri.parse(
    'https://wa.me/$numero?text=${Uri.encodeComponent(message)}',
  );
}

/// Opens WhatsApp in the same synchronous turn as the user tap (required on iOS Safari).
bool openWhatsAppImmediately({
  required String phone,
  required String message,
}) {
  final numero = formatWhatsAppNumber(
    phone.trim().isEmpty ? kDefaultConsultantWhatsApp : phone,
  );
  final url =
      'https://wa.me/$numero?text=${Uri.encodeComponent(message)}';
  debugPrint('[WhatsApp] número=$numero url=$url');

  if (kIsWeb) {
    return whatsapp_launcher.openWhatsAppInBrowser(url);
  }
  return false;
}

/// Opens WhatsApp with a pre-filled message.
Future<bool> openWhatsApp({
  required String phone,
  required String message,
}) async {
  if (kIsWeb) {
    return openWhatsAppImmediately(phone: phone, message: message);
  }

  final uri = buildWhatsAppUri(phone: phone, message: message);
  debugPrint('[WhatsApp] abrindo: $uri');

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
