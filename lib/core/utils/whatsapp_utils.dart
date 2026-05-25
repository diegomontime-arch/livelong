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

String _whatsappLang(String lang) {
  if (lang == 'es' || lang == 'en') return lang;
  return 'pt';
}

String _formatDependentes(String lang, dynamic raw) {
  final v = raw is int ? raw : int.tryParse('$raw');
  return switch (_whatsappLang(lang)) {
    'es' => switch (v) {
        0 => 'Solo yo',
        1 => '1 a 2 personas',
        2 => '3 a 4 personas',
        3 => '5 o más',
        _ => 'No indicado',
      },
    'en' => switch (v) {
        0 => 'Just me',
        1 => '1 to 2 people',
        2 => '3 to 4 people',
        3 => '5 or more',
        _ => 'Not specified',
      },
    _ => switch (v) {
        0 => 'Só eu mesmo',
        1 => '1 a 2 pessoas',
        2 => '3 a 4 pessoas',
        3 => '5 ou mais',
        _ => 'Não informado',
      },
  };
}

String _formatRenda(String lang, dynamic raw) {
  final v = raw is int ? raw : int.tryParse('$raw');
  return switch (_whatsappLang(lang)) {
    'es' => switch (v) {
        1 => 'Hasta \$2,000',
        2 => '\$2,000 – \$4,000',
        3 => '\$4,000 – \$7,000',
        4 => 'Más de \$7,000',
        _ => 'No indicado',
      },
    'en' => switch (v) {
        1 => 'Up to \$2,000',
        2 => '\$2,000 – \$4,000',
        3 => '\$4,000 – \$7,000',
        4 => 'Above \$7,000',
        _ => 'Not specified',
      },
    _ => switch (v) {
        1 => 'Até \$2.000',
        2 => '\$2.000 – \$4.000',
        3 => '\$4.000 – \$7.000',
        4 => 'Acima de \$7.000',
        _ => 'Não informado',
      },
  };
}

String _formatSeguro(String lang, dynamic raw) {
  final v = raw is int ? raw : int.tryParse('$raw');
  return switch (_whatsappLang(lang)) {
    'es' => switch (v) {
        0 => 'No',
        1 => 'Sí, cobertura básica',
        2 => 'Sí, por el trabajo',
        3 => 'Sí, cobertura completa',
        _ => 'No indicado',
      },
    'en' => switch (v) {
        0 => 'No',
        1 => 'Yes, basic coverage',
        2 => 'Yes, through work',
        3 => 'Yes, full coverage',
        _ => 'Not specified',
      },
    _ => switch (v) {
        0 => 'Não',
        1 => 'Sim, cobertura básica',
        2 => 'Sim, pelo trabalho',
        3 => 'Sim, cobertura completa',
        _ => 'Não informado',
      },
  };
}

String _formatPreocupacao(String lang, dynamic raw) {
  final key = raw?.toString() ?? '';
  return switch (_whatsappLang(lang)) {
    'es' => switch (key) {
        'moradia' => 'Pagar alquiler o hipoteca',
        'educacao' => 'Educación de los hijos',
        'dividas' => 'Deudas y facturas',
        'familia' => 'Futuro de la familia en general',
        _ => 'No indicado',
      },
    'en' => switch (key) {
        'moradia' => 'Paying rent or mortgage',
        'educacao' => "Children's education",
        'dividas' => 'Debts and bills',
        'familia' => "Family's future in general",
        _ => 'Not specified',
      },
    _ => switch (key) {
        'moradia' => 'Pagar o aluguel ou hipoteca',
        'educacao' => 'Educação dos filhos',
        'dividas' => 'Dívidas e contas',
        'familia' => 'Futuro da família em geral',
        _ => 'Não informado',
      },
  };
}

String _agentOutreachMessage({
  required String lang,
  required int score,
  String? nome,
}) {
  final first = nome?.trim().split(' ').firstWhere(
        (p) => p.isNotEmpty,
        orElse: () => '',
      ) ??
      '';
  final greeting = first.isNotEmpty ? ' $first' : '';

  if (lang == 'es') {
    return '¡Hola$greeting! Vi tu diagnóstico de protección familiar '
        '($score%). Soy tu consultor M4LIFE — ¿podemos hablar?';
  }
  if (lang == 'en') {
    return 'Hi$greeting! I saw your family protection diagnosis '
        '($score%). I\'m your M4LIFE consultant — can we talk?';
  }
  return 'Olá$greeting! Vi seu diagnóstico de proteção familiar '
      '($score%). Sou seu consultor M4LIFE — podemos conversar?';
}

String _prospectToAgentMessage({
  required String lang,
  required int score,
  required String nome,
  required String telefone,
  required Map<String, dynamic> answers,
}) {
  final l = _whatsappLang(lang);
  final dependentes = _formatDependentes(l, answers['dependentes']);
  final renda = _formatRenda(l, answers['renda']);
  final seguro = _formatSeguro(l, answers['seguro']);
  final preocupacao = _formatPreocupacao(l, answers['preocupacao']);

  if (l == 'es') {
    return '\u{1F514} ¡Hola! Acabo de hacer el diagnóstico de protección familiar por M4LIFE USA.\n\n'
        '\u{1F464} Mi nombre: $nome\n'
        '\u{1F4F1} Mi teléfono: $telefone\n'
        '\u{2B50} Mi score: $score% de protección\n\n'
        '\u{1F4CA} Mi perfil:\n'
        '\u{2022} Dependientes: $dependentes\n'
        '\u{2022} Ingreso mensual: $renda\n'
        '\u{2022} Tengo seguro actual: $seguro\n'
        '\u{2022} Mi mayor preocupación: $preocupacao\n\n'
        'Me gustaría saber más sobre las opciones disponibles para mi familia.';
  }
  if (l == 'en') {
    return '\u{1F514} Hi! I just completed the family protection diagnosis through M4LIFE USA.\n\n'
        '\u{1F464} My name: $nome\n'
        '\u{1F4F1} My phone: $telefone\n'
        '\u{2B50} My score: $score% protection level\n\n'
        '\u{1F4CA} My profile:\n'
        '\u{2022} Dependents: $dependentes\n'
        '\u{2022} Monthly income: $renda\n'
        '\u{2022} Current life insurance: $seguro\n'
        '\u{2022} My biggest concern: $preocupacao\n\n'
        'I would like to learn more about the options available for my family.';
  }
  return '\u{1F514} Olá! Acabei de fazer o diagnóstico de proteção familiar pela M4LIFE USA.\n\n'
      '\u{1F464} Meu nome: $nome\n'
      '\u{1F4F1} Meu telefone: $telefone\n'
      '\u{2B50} Meu score: $score% de proteção\n\n'
      '\u{1F4CA} Meu perfil:\n'
      '\u{2022} Dependentes: $dependentes\n'
      '\u{2022} Renda mensal: $renda\n'
      '\u{2022} Tenho seguro atual: $seguro\n'
      '\u{2022} Minha maior preocupação: $preocupacao\n\n'
      'Gostaria de saber mais sobre as opções disponíveis para minha família.';
}

/// WhatsApp message text. Use [prospectToAgent] when the prospect contacts the agent.
String buildLeadWhatsAppMessage({
  required String lang,
  required int score,
  String? nome,
  String? telefone,
  Map<String, dynamic>? answers,
  bool prospectToAgent = false,
}) {
  if (!prospectToAgent) {
    return _agentOutreachMessage(lang: lang, score: score, nome: nome);
  }

  final name = nome?.trim() ?? '';
  final phone = telefone?.trim() ?? '';
  if (name.isEmpty || phone.isEmpty) {
    return _agentOutreachMessage(lang: lang, score: score, nome: nome);
  }

  return _prospectToAgentMessage(
    lang: lang,
    score: score,
    nome: name,
    telefone: phone,
    answers: answers ?? const {},
  );
}
