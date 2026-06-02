import 'package:flutter/material.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';

/// Responsive shell for the public prospect flow.
///
/// **Single URL** — no separate mobile/desktop routes. Layout follows viewport width:
/// - width &lt; [desktopBreakpoint]: full-screen mobile UI
/// - width ≥ [desktopBreakpoint]: two columns (branding + phone card)
///
/// Every public lead screen must use this wrapper: LanguageScreen, WelcomeScreen,
/// OnboardingScreen, QuestionScreen, ResultScreen, ChatScreen.
///
/// Routes: `/` and `/a/:sellerSlug` only (`app_router.dart`).
class PublicLeadFlowScaffold extends StatelessWidget {
  const PublicLeadFlowScaffold({
    super.key,
    required this.child,
    this.lang,
  });

  final Widget child;
  final String? lang;

  static const double desktopBreakpoint = 900;
  static const double phoneCardWidth = 420;
  static const double phoneCardMaxHeight = 900;

  static bool isDesktopLayout(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= desktopBreakpoint;
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktopLayout(context)) {
      return Scaffold(
        backgroundColor: AppColors.black,
        body: child,
      );
    }

    final maxHeight = MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).vertical -
        48;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF050505),
              Color(0xFF0F0D08),
              Color(0xFF050505),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _DesktopBrandingPanel(lang: lang)),
                    const SizedBox(width: 48),
                    SizedBox(
                      width: phoneCardWidth,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: maxHeight.clamp(560, phoneCardMaxHeight),
                        ),
                        child: _PhoneFrame(child: child),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.08),
            blurRadius: 48,
            spreadRadius: 0,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: child,
      ),
    );
  }
}

class _DesktopBrandingPanel extends StatelessWidget {
  const _DesktopBrandingPanel({this.lang});

  final String? lang;

  Map<String, String> get _copy {
    final l = lang ?? 'en';
    const data = {
      'pt': {
        'eyebrow': 'PROTEÇÃO INTELIGENTE',
        'title': 'Descubra o nível de proteção da sua família em minutos.',
        'body':
            'Responda perguntas simples e receba uma análise educacional personalizada — com orientação de um consultor licenciado.',
        'b1': 'Menos de 2 minutos',
        'b2': '100% confidencial',
        'b3': 'Resultado personalizado',
        'footer': 'Ferramenta educacional · Não constitui aconselhamento de seguros',
      },
      'es': {
        'eyebrow': 'PROTECCIÓN INTELIGENTE',
        'title': 'Descubre el nivel de protección de tu familia en minutos.',
        'body':
            'Responde preguntas simples y recibe un análisis educativo personalizado — con orientación de un consultor licenciado.',
        'b1': 'Menos de 2 minutos',
        'b2': '100% confidencial',
        'b3': 'Resultado personalizado',
        'footer': 'Herramienta educativa · No constituye asesoramiento de seguros',
      },
      'en': {
        'eyebrow': 'SMART PROTECTION',
        'title': 'Discover your family protection level in minutes.',
        'body':
            'Answer a few simple questions and get a personalized educational analysis — with guidance from a licensed consultant.',
        'b1': 'Under 2 minutes',
        'b2': '100% confidential',
        'b3': 'Personalized results',
        'footer': 'Educational tool · Not insurance advice',
      },
    };
    return data[l] ?? data['en']!;
  }

  String _t(String key) => _copy[key]!;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const HitLookDiscreteBadge(),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
            ),
            child: Text(
              _t('eyebrow').toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.gold,
                letterSpacing: 2.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _t('title'),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _t('body'),
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.greyLight,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          _BrandBullet(icon: Icons.timer_outlined, text: _t('b1')),
          const SizedBox(height: 12),
          _BrandBullet(icon: Icons.lock_outline, text: _t('b2')),
          const SizedBox(height: 12),
          _BrandBullet(icon: Icons.insights_outlined, text: _t('b3')),
          const SizedBox(height: 40),
          Text(
            _t('footer'),
            style: TextStyle(
              fontSize: 11,
              color: AppColors.grey.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandBullet extends StatelessWidget {
  const _BrandBullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, size: 18, color: AppColors.gold),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.whitesoft,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
