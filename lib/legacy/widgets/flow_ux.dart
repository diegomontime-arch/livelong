import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hitlook/legacy/screens/agent_profile.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';

/// MM/DD/YYYY mask for US-style birth dates.
class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 8; i++) {
      if (i == 2 || i == 4) buf.write('/');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Runs [action] with a timeout; returns null on timeout.
Future<T?> runWithTimeout<T>(
  Future<T> Function() action, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  try {
    return await action().timeout(timeout);
  } on TimeoutException {
    return null;
  }
}

bool isNetworkError(Object e) {
  final msg = e.toString().toLowerCase();
  return msg.contains('network') ||
      msg.contains('connection') ||
      msg.contains('unavailable') ||
      msg.contains('failed host lookup');
}

bool isRealPublicAgent(AgentProfile profile, String agentId) {
  if (agentId.isEmpty || agentId == 'default') return true;
  if (profile.fotoUrl.trim().isNotEmpty) return true;
  final name = profile.resolvedNome;
  if (name.isNotEmpty && name != AgentProfile.defaultProfile.nome) {
    return true;
  }
  return profile.userId != null &&
      profile.userId!.isNotEmpty &&
      profile.hasSaaSContext;
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Formata data/hora sem depender de [initializeDateFormatting] (evita LocaleDataException na web).
String formatLeadDate(dynamic value, {String locale = 'pt_BR'}) {
  DateTime? dt;
  if (value is Timestamp) {
    dt = value.toDate();
  } else if (value is DateTime) {
    dt = value;
  }
  if (dt == null) return '—';
  return '${_two(dt.day)}/${_two(dt.month)}/${dt.year} ${_two(dt.hour)}:${_two(dt.minute)}';
}

String leadDisplayName(Map<String, dynamic> lead) {
  final raw = lead['nome'] ?? lead['prospectName'] ?? lead['name'];
  if (raw == null || raw.toString().trim().isEmpty) {
    return 'Nome não informado';
  }
  return raw.toString();
}

String leadDisplayPhone(Map<String, dynamic> lead) {
  final raw = lead['telefone'] ?? lead['prospectPhone'] ?? lead['phone'];
  return raw?.toString() ?? '';
}

int leadDisplayScore(Map<String, dynamic> lead) {
  final score = lead['score'] ?? 0;
  if (score is int) return score;
  return int.tryParse('$score') ?? 0;
}

DateTime? leadCreatedAt(Map<String, dynamic> lead) {
  final value = lead['createdAt'];
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

class FlowBackButton extends StatelessWidget {
  const FlowBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onPressed ??
            () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/');
              }
            },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.blackCard,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.gold.withOpacity(0.25)),
          ),
          child: const Icon(Icons.arrow_back, size: 18, color: AppColors.gold),
        ),
      ),
    );
  }
}

class FlowLoadingView extends StatelessWidget {
  const FlowLoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.gold),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(color: AppColors.greyLight, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class FlowErrorView extends StatelessWidget {
  const FlowErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Tentar novamente',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 48, color: AppColors.gold),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.greyLight,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.gold,
                  side: BorderSide(color: AppColors.gold.withOpacity(0.5)),
                ),
                child: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AgentNotFoundScreen extends StatelessWidget {
  const AgentNotFoundScreen({
    super.key,
    required this.lang,
    this.agentId = '',
  });

  final String lang;
  final String agentId;

  String _t(String key) {
    const m = {
      'pt': {
        'title': 'Link não encontrado',
        'desc':
            'Este consultor ainda não está disponível ou o link está incorreto.',
        'btn': 'IR PARA A PÁGINA INICIAL',
      },
      'es': {
        'title': 'Enlace no encontrado',
        'desc':
            'Este consultor aún no está disponible o el enlace es incorrecto.',
        'btn': 'IR A LA PÁGINA PRINCIPAL',
      },
      'en': {
        'title': 'Link not found',
        'desc':
            'This consultant is not available yet or the link is incorrect.',
        'btn': 'GO TO HOME PAGE',
      },
    };
    return m[lang]?[key] ?? m['pt']![key]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: WatermarkBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                const FlowBackButton(),
                const Spacer(),
                const Icon(Icons.link_off, size: 56, color: AppColors.gold),
                const SizedBox(height: 24),
                Text(
                  _t('title'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _t('desc'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.greyLight,
                    height: 1.6,
                  ),
                ),
                if (agentId.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    agentId,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.grey.withOpacity(0.7),
                    ),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => context.go('/'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.black,
                    ),
                    child: Text(
                      _t('btn'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmExitFlow(BuildContext context, String lang) async {
  final title = lang == 'en'
      ? 'Leave?'
      : lang == 'es'
          ? '¿Salir?'
          : 'Sair?';
  final body = lang == 'en'
      ? 'Are you sure you want to leave? Your progress will be lost.'
      : lang == 'es'
          ? '¿Seguro que quieres salir? Perderás tu progreso.'
          : 'Tem certeza que deseja sair? Seu progresso será perdido.';
  final leave = lang == 'en'
      ? 'Leave'
      : lang == 'es'
          ? 'Salir'
          : 'Sair';
  final stay = lang == 'en'
      ? 'Stay'
      : lang == 'es'
          ? 'Quedarme'
          : 'Continuar';

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.blackCard,
      title: Text(title, style: const TextStyle(color: AppColors.white)),
      content: Text(body, style: const TextStyle(color: AppColors.greyLight)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(stay, style: const TextStyle(color: AppColors.gold)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(leave, style: const TextStyle(color: AppColors.greyLight)),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Exit confirmation on browser back / system back (public lead flow).
class FlowExitGuard extends StatelessWidget {
  const FlowExitGuard({super.key, required this.lang, required this.child});

  final String lang;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmExitFlow(context, lang);
        if (leave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}
