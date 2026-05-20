import 'package:url_launcher/url_launcher.dart';

/// Normalizes a phone number for wa.me (digits only; US 10-digit → prepend 1).
String normalizeWhatsAppNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  if (digits.length == 10) return '1$digits';
  return digits;
}

/// Opens WhatsApp with a pre-filled message.
Future<bool> openWhatsApp({
  required String phone,
  required String message,
}) async {
  final numero = normalizeWhatsAppNumber(phone);
  if (numero.isEmpty) return false;

  final uri = Uri.parse(
    'https://wa.me/$numero?text=${Uri.encodeComponent(message)}',
  );
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

String buildLeadWhatsAppMessage({
  required String lang,
  required int score,
}) {
  if (lang == 'es') {
    return '¡Hola! Acabo de hacer el diagnóstico de protección familiar y '
        'recibí una puntuación de $score%. Me gustaría saber más sobre las '
        'opciones disponibles.';
  }
  if (lang == 'en') {
    return 'Hi! I just completed the family protection assessment and '
        'received a score of $score%. I would like to learn more about the '
        'available options.';
  }
  return 'Olá! Acabei de fazer o diagnóstico de proteção familiar e recebi '
      'um score de $score%. Gostaria de saber mais sobre as opções disponíveis.';
}
