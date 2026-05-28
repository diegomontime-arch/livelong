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

/// US-style display only (e.g. 17868525672 → +1 (786) 852-5672). Not for wa.me links.
String formatPhoneForWhatsAppMessage(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.length == 11 && digits.startsWith('1')) {
    return '+1 (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-${digits.substring(7)}';
  }
  if (digits.length == 10) {
    return '+1 (${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
  }
  final trimmed = raw.trim();
  return trimmed.isNotEmpty ? trimmed : digits;
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
  required String nascimento,
  required Map<String, dynamic> answers,
}) {
  final l = _whatsappLang(lang);
  final phoneDisplay = formatPhoneForWhatsAppMessage(telefone);
  final birthDisplay = nascimento.trim().isNotEmpty ? nascimento.trim() : '—';
  final dependentes = _formatDependentes(l, answers['dependentes']);
  final renda = _formatRenda(l, answers['renda']);
  final seguro = _formatSeguro(l, answers['seguro']);
  final preocupacao = _formatPreocupacao(l, answers['preocupacao']);

  if (l == 'es') {
    return '\u{1F514} ¡Hola! Acabo de hacer el diagnóstico de protección familiar por M4LIFE USA.\n\n'
        '\u{1F464} Mi nombre: $nome\n'
        '\u{1F4F1} Mi teléfono: $phoneDisplay\n'
        '\u{1F382} Fecha de nacimiento: $birthDisplay\n'
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
        '\u{1F4F1} My phone: $phoneDisplay\n'
        '\u{1F382} Date of birth: $birthDisplay\n'
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
      '\u{1F4F1} Meu telefone: $phoneDisplay\n'
      '\u{1F382} Data de nascimento: $birthDisplay\n'
      '\u{2B50} Meu score: $score% de proteção\n\n'
      '\u{1F4CA} Meu perfil:\n'
      '\u{2022} Dependentes: $dependentes\n'
      '\u{2022} Renda mensal: $renda\n'
      '\u{2022} Tenho seguro atual: $seguro\n'
      '\u{2022} Minha maior preocupação: $preocupacao\n\n'
      'Gostaria de saber mais sobre as opções disponíveis para minha família.';
}

/// Rule-based approach guide for the agent (appended to prospect WhatsApp message).
String generateApproachSuggestion({
  required String lang,
  required int score,
  required Map<String, dynamic> answers,
}) {
  final l = _whatsappLang(lang);
  final dependentes = answers['dependentes'] is int
      ? answers['dependentes'] as int
      : int.tryParse('${answers['dependentes']}') ?? 0;
  final renda = answers['renda'] is int
      ? answers['renda'] as int
      : int.tryParse('${answers['renda']}') ?? 1;
  final seguro = answers['seguro'] is int
      ? answers['seguro'] as int
      : int.tryParse('${answers['seguro']}') ?? 0;
  final preocupacao = answers['preocupacao']?.toString() ?? '';
  final momento = (answers['momento']?.toString() ?? '').toLowerCase().trim();

  String dependentesLabel() => switch (dependentes) {
        0 => l == 'es'
            ? 'solo'
            : l == 'en'
                ? 'solo'
                : 'sozinho(a)',
        1 => l == 'es'
            ? '1–2 dependientes'
            : l == 'en'
                ? '1–2 dependents'
                : '1–2 dependentes',
        2 => l == 'es'
            ? '3–4 dependientes'
            : l == 'en'
                ? '3–4 dependents'
                : '3–4 dependentes',
        _ => l == 'es'
            ? 'familia grande (5+)'
            : l == 'en'
                ? 'large family (5+)'
                : 'família grande (5+)',
      };

  String rendaLabel() => switch (renda) {
        1 => l == 'es'
            ? 'hasta \$2K/mes'
            : l == 'en'
                ? 'up to \$2K/mo'
                : 'até \$2K/mês',
        2 => l == 'es'
            ? '\$2–4K/mes'
            : l == 'en'
                ? '\$2–4K/mo'
                : '\$2–4K/mês',
        3 => l == 'es'
            ? '\$4–7K/mes'
            : l == 'en'
                ? '\$4–7K/mo'
                : '\$4–7K/mês',
        _ => l == 'es'
            ? 'más de \$7K/mes'
            : l == 'en'
                ? 'above \$7K/mo'
                : 'acima \$7K/mês',
      };

  String seguroLabel() => switch (seguro) {
        0 => l == 'es'
            ? 'sin seguro'
            : l == 'en'
                ? 'no coverage'
                : 'sem seguro',
        1 => l == 'es'
            ? 'seguro básico'
            : l == 'en'
                ? 'basic coverage'
                : 'seguro básico',
        2 => l == 'es'
            ? 'por el trabajo'
            : l == 'en'
                ? 'through work'
                : 'pelo trabalho',
        _ => l == 'es'
            ? 'seguro completo'
            : l == 'en'
                ? 'full coverage'
                : 'seguro completo',
      };

  String preocupacaoLabel() => switch (preocupacao) {
        'moradia' => l == 'es'
            ? 'vivienda'
            : l == 'en'
                ? 'housing'
                : 'moradia',
        'educacao' => l == 'es'
            ? 'educación'
            : l == 'en'
                ? 'education'
                : 'educação',
        'dividas' => l == 'es'
            ? 'deudas'
            : l == 'en'
                ? 'debts'
                : 'dívidas',
        'familia' => l == 'es'
            ? 'familia'
            : l == 'en'
                ? 'family'
                : 'família',
        _ => l == 'es'
            ? 'general'
            : l == 'en'
                ? 'general'
                : 'geral',
      };

  final hasNoCoverage = seguro == 0;
  final largeFamily = dependentes >= 2;

  // ── Parte 1: Perfil (uma linha)
  final profile = () {
    final parts = <String>[
      dependentesLabel(),
      seguroLabel(),
      l == 'es'
          ? 'ingreso ${rendaLabel()}'
          : l == 'en'
              ? 'income ${rendaLabel()}'
              : 'renda ${rendaLabel()}',
      l == 'es'
          ? 'preocupación: ${preocupacaoLabel()}'
          : l == 'en'
              ? 'concern: ${preocupacaoLabel()}'
              : 'preocupação: ${preocupacaoLabel()}',
    ];

    if (momento == 'urgente') {
      parts.add(l == 'es' ? 'momento: urgente' : l == 'en' ? 'timing: urgent' : 'momento: urgente');
    } else if (momento == 'pesquisando') {
      parts.add(l == 'es' ? 'momento: investigando' : l == 'en' ? 'timing: researching' : 'momento: pesquisando');
    } else if (momento == 'curioso') {
      parts.add(l == 'es' ? 'momento: curioso' : l == 'en' ? 'timing: curious' : 'momento: curioso');
    }

    return parts.join(', ');
  }();

  // ── Parte 2: Como abrir
  final opener = () {
    if (preocupacao == 'educacao') {
      return l == 'es'
          ? 'Vi que tienes hijos y piensas en su futuro. ¿Sabías que en EE.UU. una universidad puede costar hasta \$200K? Déjame mostrarte cómo protegerte de eso.'
          : l == 'en'
              ? 'I saw you care about your kids’ future. Did you know a US college can cost up to \$200K? Let me show you a simple way to protect that.'
              : 'Vi que você tem filhos e pensa no futuro deles. Sabia que nos EUA uma faculdade pode custar até \$200K? Deixa eu te mostrar como se proteger disso.';
    }
    if (preocupacao == 'dividas') {
      return l == 'es'
          ? 'Vi que tienes deudas. Si algo te pasara mañana, ¿tu familia podría pagar todo? Tengo una solución que protege exactamente eso.'
          : l == 'en'
              ? 'I saw you have debts. If something happened tomorrow, could your family handle the bills? I have a solution that protects exactly that.'
              : 'Vi que você tem dívidas. Se algo acontecer com você amanhã, sua família consegue pagar tudo? Tenho uma solução que protege exatamente isso.';
    }
    if (preocupacao == 'familia') {
      return l == 'es'
          ? 'Pusiste que tu familia es tu mayor prioridad. Te voy a mostrar cómo garantizar que estén bien pase lo que pase.'
          : l == 'en'
              ? 'You said your family is your top priority. I’ll show you how to make sure they’re protected no matter what happens.'
              : 'Você respondeu que sua família é sua maior prioridade. Vou te mostrar como garantir que eles fiquem bem independente do que acontecer.';
    }
    if (preocupacao == 'moradia') {
      return l == 'es'
          ? 'Vi que tu prioridad es la vivienda. Si faltara tu ingreso por un tiempo, ¿la casa seguiría segura? Te muestro una protección práctica para eso.'
          : l == 'en'
              ? 'I saw housing is your main concern. If your income stopped for a while, would the home stay safe? I can show you practical protection for that.'
              : 'Vi que sua prioridade é moradia. Se sua renda faltasse por um tempo, a casa continuaria segura? Te mostro uma proteção prática pra isso.';
    }
    if (hasNoCoverage) {
      return l == 'es'
          ? 'Ahora estás 100% sin protección. La buena noticia: con menos de \$50/mes ya puedes cambiar eso. ¿Te muestro opciones?'
          : l == 'en'
              ? 'Right now you’re 100% unprotected. Good news: for under \$50/month you can change that. Want me to show options?'
              : 'Você está 100% desprotegido agora. Mas a boa notícia é que com menos de \$50/mês você já muda isso. Quer que eu te mostre as opções?';
    }
    return l == 'es'
        ? 'Vi tu diagnóstico y tu score. Te propongo algo simple: en 10 minutos te muestro una opción que encaja con tu perfil.'
        : l == 'en'
            ? 'I saw your diagnosis and score. Here’s a simple plan: in 10 minutes I’ll show an option that fits your profile.'
            : 'Vi seu diagnóstico e seu score. Te proponho algo simples: em 10 minutos eu te mostro uma opção que encaixa no seu perfil.';
  }();

  // ── Parte 3: O que oferecer
  final offer = () {
    if (score < 30 && largeFamily && hasNoCoverage) {
      return l == 'es'
          ? 'Empieza con Term Life de \$250K (o más si el presupuesto lo permite) para cubrir familia y deudas. Menciona el Living Benefit desde el inicio.'
          : l == 'en'
              ? 'Start with a \$250K Term Life (or higher if budget allows) to cover family + debts. Mention the Living Benefit early.'
              : 'Comece com Term Life de \$250K (ou mais se couber no orçamento) — cobre família e dívidas. Mencione o Living Benefit logo no início.';
    }
    if (score < 60 && (seguro == 1 || seguro == 2)) {
      return l == 'es'
          ? 'Ofrece upgrade a un plan con Living Benefit: argumento principal = seguro que puede pagar en vida, no solo al fallecer.'
          : l == 'en'
              ? 'Offer an upgrade to a plan with Living Benefit: main angle = insurance that can pay while alive, not only at death.'
              : 'Ofereça upgrade para plano com Living Benefit — argumento: seguro que paga em vida, não só na morte.';
    }
    if (score >= 60) {
      return l == 'es'
          ? 'El prospect ya tiene una base. Enfócate en optimizar: más cobertura para hijos, ajustar duración del Term, y revisar gaps (educación/hipoteca).'
          : l == 'en'
              ? 'Prospect already has a base. Focus on optimization: more coverage for kids, term length, and closing gaps (college/mortgage).'
              : 'Prospect já tem base. Foco em otimização e em aumentar cobertura para os filhos (educação/hipoteca) e fechar gaps.';
    }
    if (hasNoCoverage) {
      return l == 'es'
          ? 'Prioriza poner cobertura básica hoy (Term Life). Después, presenta Living Benefit como diferencial para subir el nivel.'
          : l == 'en'
              ? 'Prioritize getting basic coverage in place today (Term Life). Then introduce Living Benefit as the differentiator to level up.'
              : 'Priorize colocar uma proteção básica hoje (Term Life). Depois, apresente o Living Benefit como diferencial para subir o nível.';
    }
    return l == 'es'
        ? 'Haz una recomendación simple en 2 opciones (básico vs. mejor) y guía por presupuesto. Incluye Living Benefit como diferencial.'
        : l == 'en'
            ? 'Give a simple 2-option recommendation (basic vs. better) guided by budget. Include Living Benefit as a differentiator.'
            : 'Faça recomendação simples em 2 opções (básico vs. melhor) guiando por orçamento. Inclua Living Benefit como diferencial.';
  }();

  String t(String pt, String es, String en) => l == 'es' ? es : l == 'en' ? en : pt;

  return '\n\n'
      '👤 ${t('PERFIL', 'PERFIL', 'PROFILE')}\n'
      '$profile\n\n'
      '💬 ${t('COMO ABRIR', 'CÓMO ABRIR', 'HOW TO OPEN')}\n'
      '"$opener"\n\n'
      '🎯 ${t('O QUE OFERECER', 'QUÉ OFRECER', 'WHAT TO OFFER')}\n'
      '$offer';
}

/// WhatsApp message text. Use [prospectToAgent] when the prospect contacts the agent.
String buildLeadWhatsAppMessage({
  required String lang,
  required int score,
  String? nome,
  String? telefone,
  String? nascimento,
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
    nascimento: nascimento?.trim() ?? '',
    answers: answers ?? const <String, dynamic>{},
  );
}
