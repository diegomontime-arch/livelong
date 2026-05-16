import 'package:flutter/material.dart';
import 'questions_screen.dart';
import 'agent_profile.dart';

class AppColors {
  static const black = Color(0xFF000000);
  static const blackCard = Color(0xFF0D0D0D);
  static const blackLight = Color(0xFF141414);
  static const gold = Color(0xFFD4AF37);
  static const goldDim = Color(0xFF8B7420);
  static const goldGlow = Color(0x22D4AF37);
  static const white = Color(0xFFFFFFFF);
  static const whiteWarm = Color(0xFFF5F0EB);
  static const whitesoft = Color(0xFFE8E8E8);
  static const grey = Color(0xFF555555);
  static const greyLight = Color(0xFF888888);
  static const accentDim = Color(0xFF222222);
}

// ─── CORUJA ───────────────────────────────────────────────
class OwlMark extends StatelessWidget {
  final double size;
  final double opacity;
  const OwlMark({super.key, this.size = 40, this.opacity = 0.07});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _OwlPainter()),
      ),
    );
  }
}

class _OwlPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFFD4AF37)
      ..strokeWidth = size.width * 0.07
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Corpo
    final body = Path()
      ..moveTo(w * 0.5, h * 0.1)
      ..lineTo(w * 0.88, h * 0.3)
      ..lineTo(w * 0.88, h * 0.72)
      ..lineTo(w * 0.5, h * 0.92)
      ..lineTo(w * 0.12, h * 0.72)
      ..lineTo(w * 0.12, h * 0.3)
      ..close();
    canvas.drawPath(body, stroke);

    // Orelha esquerda
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.25, h * 0.2)
        ..lineTo(w * 0.18, h * 0.02)
        ..lineTo(w * 0.36, h * 0.14),
      stroke,
    );

    // Orelha direita
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.75, h * 0.2)
        ..lineTo(w * 0.82, h * 0.02)
        ..lineTo(w * 0.64, h * 0.14),
      stroke,
    );

    // Olho esquerdo
    canvas.drawCircle(Offset(w * 0.34, h * 0.43), w * 0.12, stroke);
    canvas.drawCircle(Offset(w * 0.34, h * 0.43), w * 0.04, fill);

    // Olho direito
    canvas.drawCircle(Offset(w * 0.66, h * 0.43), w * 0.12, stroke);
    canvas.drawCircle(Offset(w * 0.66, h * 0.43), w * 0.04, fill);

    // Bico
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.41, h * 0.56)
        ..lineTo(w * 0.5, h * 0.65)
        ..lineTo(w * 0.59, h * 0.56)
        ..close(),
      fill,
    );

    // Garra esquerda
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.28, h * 0.87)
        ..lineTo(w * 0.18, h * 0.98)
        ..moveTo(w * 0.28, h * 0.87)
        ..lineTo(w * 0.28, h * 1.0)
        ..moveTo(w * 0.28, h * 0.87)
        ..lineTo(w * 0.38, h * 0.98),
      stroke,
    );

    // Garra direita
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.72, h * 0.87)
        ..lineTo(w * 0.62, h * 0.98)
        ..moveTo(w * 0.72, h * 0.87)
        ..lineTo(w * 0.72, h * 1.0)
        ..moveTo(w * 0.72, h * 0.87)
        ..lineTo(w * 0.82, h * 0.98),
      stroke,
    );
  }

  @override
  bool shouldRepaint(CustomPainter old) => false;
}

// ─── WATERMARK ────────────────────────────────────────────
class WatermarkBackground extends StatelessWidget {
  final Widget child;
  const WatermarkBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Grid sutil
        Positioned.fill(
          child: Opacity(
            opacity: 0.015,
            child: CustomPaint(painter: _GridPainter()),
          ),
        ),

        // M4LIFE marca dagua
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Center(
            child: Opacity(
              opacity: 0.022,
              child: Text(
                'M4LIFE',
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  color: AppColors.gold,
                  letterSpacing: 16,
                ),
              ),
            ),
          ),
        ),

        // Coruja canto inferior direito
        const Positioned(
          bottom: 18,
          right: 18,
          child: OwlMark(size: 44, opacity: 0.09),
        ),

        // Indicador AI
        Positioned(
          top: 14,
          right: 14,
          child: _AiIndicator(),
        ),

        // Conteúdo
        child,
      ],
    );
  }
}

class _AiIndicator extends StatefulWidget {
  @override
  State<_AiIndicator> createState() => _AiIndicatorState();
}

class _AiIndicatorState extends State<_AiIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'AI',
            style: TextStyle(
              fontSize: 8,
              color: AppColors.gold.withOpacity(0.3),
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withOpacity(_pulse.value),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFD4AF37)
      ..strokeWidth = 0.4;
    const spacing = 44.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(CustomPainter old) => false;
}

// ─── M4LIFE LOGO WIDGET ───────────────────────────────────
class M4LifeLogo extends StatelessWidget {
  final double fontSize;
  final bool showTagline;
  const M4LifeLogo(
      {super.key, this.fontSize = 38, this.showTagline = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Linha dourada vertical
        Container(
          width: 3,
          height: fontSize * 1.3,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.gold,
                AppColors.goldDim,
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'M',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      color: AppColors.white,
                      letterSpacing: 1,
                      height: 1,
                    ),
                  ),
                  TextSpan(
                    text: '4',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      color: AppColors.gold,
                      letterSpacing: 1,
                      height: 1,
                    ),
                  ),
                  TextSpan(
                    text: 'LIFE',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      color: AppColors.white,
                      letterSpacing: 3,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            if (showTagline) ...[
              const SizedBox(height: 3),
              Text(
                'MONEY FOR LIFE USA',
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.greyLight,
                  letterSpacing: 3.5,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ─── LANGUAGE SCREEN ──────────────────────────────────────
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _select(String lang) {
    setState(() => _selected = lang);
    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => WelcomeScreen(lang: lang),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: WatermarkBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const M4LifeLogo(fontSize: 42),

                    const SizedBox(height: 56),

                    // Divisor dourado
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppColors.goldDim.withOpacity(0.3),
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'SELECT LANGUAGE',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.greyLight,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppColors.goldDim.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    _LangButton(
                      flag: '🇧🇷',
                      language: 'Português',
                      sublabel: 'Brasil',
                      selected: _selected == 'pt',
                      onTap: () => _select('pt'),
                    ),
                    const SizedBox(height: 10),
                    _LangButton(
                      flag: '🇪🇸',
                      language: 'Español',
                      sublabel: 'Latinoamérica',
                      selected: _selected == 'es',
                      onTap: () => _select('es'),
                    ),
                    const SizedBox(height: 10),
                    _LangButton(
                      flag: '🇺🇸',
                      language: 'English',
                      sublabel: 'United States',
                      selected: _selected == 'en',
                      onTap: () => _select('en'),
                    ),

                    const SizedBox(height: 48),

                    Text(
                      'AI · PROTECTION · SALES',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.goldDim.withOpacity(0.6),
                        letterSpacing: 3,
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

class _LangButton extends StatefulWidget {
  final String flag;
  final String language;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  const _LangButton({
    required this.flag,
    required this.language,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_LangButton> createState() => _LangButtonState();
}

class _LangButtonState extends State<_LangButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _pressed;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: active
              ? AppColors.gold.withOpacity(0.1)
              : AppColors.blackCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? AppColors.gold
                : AppColors.gold.withOpacity(0.15),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(widget.flag,
                style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.language,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: active
                          ? AppColors.gold
                          : AppColors.white,
                    ),
                  ),
                  Text(
                    widget.sublabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: active
                          ? AppColors.gold.withOpacity(0.6)
                          : AppColors.greyLight,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check,
                    size: 13, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── WELCOME ──────────────────────────────────────────────
class WelcomeScreen extends StatefulWidget {
  final String lang;
  final String agentId;
  const WelcomeScreen({super.key, required this.lang, this.agentId = 'default'});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  AgentProfile _agent = AgentProfile.defaultProfile;

  @override
  void initState() {
    super.initState();
    _loadAgent();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  Future<void> _loadAgent() async {
    final agent = await AgentProvider.loadAgent(widget.agentId);
    if (mounted) setState(() => _agent = agent);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  final _texts = {
    'pt': {
      'badge': 'PROTEÇÃO INTELIGENTE',
      'title': 'Se algo\nacontecer\ncom você,',
      'subtitle': 'sua família estaria protegida?',
      'desc': 'Em menos de 2 minutos, descubra qual é o seu nível de proteção financeira hoje.',
      'b1': 'Leva menos de 2 minutos',
      'b2': 'Suas informações são privadas',
      'b3': 'Resultado personalizado para você',
      'btn': 'DESCOBRIR MEU NÍVEL DE PROTEÇÃO',
      'disc': 'Ferramenta educacional. Não constitui aconselhamento de seguros. Consulte um agente licenciado.',
    },
    'es': {
      'badge': 'PROTECCIÓN INTELIGENTE',
      'title': 'Si algo\nte pasara\na ti,',
      'subtitle': '¿tu familia estaría protegida?',
      'desc': 'En menos de 2 minutos, descubre cuál es tu nivel de protección financiera hoy.',
      'b1': 'Menos de 2 minutos',
      'b2': 'Tu información es privada',
      'b3': 'Resultado personalizado para ti',
      'btn': 'DESCUBRIR MI NIVEL DE PROTECCIÓN',
      'disc': 'Herramienta educativa. No constituye asesoramiento de seguros. Consulte un agente licenciado.',
    },
    'en': {
      'badge': 'SMART PROTECTION',
      'title': 'If something\nhappened\nto you,',
      'subtitle': 'would your family be protected?',
      'desc': 'In less than 2 minutes, discover your financial protection level today.',
      'b1': 'Takes less than 2 minutes',
      'b2': 'Your information is private',
      'b3': 'Personalized result for you',
      'btn': 'DISCOVER MY PROTECTION LEVEL',
      'disc': 'Educational tool only. Does not constitute insurance advice. Consult a licensed agent.',
    },
  };

  String _t(String key) =>
      _texts[widget.lang]?[key] ?? _texts['pt']![key]!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: WatermarkBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 36),

                    const M4LifeLogo(fontSize: 22, showTagline: true),

                    const SizedBox(height: 16),

                    // Card do agente
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: AgentCard(agent: _agent),
                    ),

                    const SizedBox(height: 24),

                    // Badge dourado
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                            color: AppColors.gold.withOpacity(0.3)),
                      ),
                      child: Text(
                        _t('badge'),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.gold,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      _t('title'),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: AppColors.white,
                        height: 1.1,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      _t('subtitle'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w300,
                        color: AppColors.gold,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      _t('desc'),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.greyLight,
                        height: 1.65,
                      ),
                    ),

                    const Spacer(),

                    _BenefitRow(
                        icon: Icons.access_time_outlined,
                        text: _t('b1')),
                    const SizedBox(height: 12),
                    _BenefitRow(
                        icon: Icons.lock_outline, text: _t('b2')),
                    const SizedBox(height: 12),
                    _BenefitRow(
                        icon: Icons.verified_outlined, text: _t('b3')),

                    const SizedBox(height: 36),

                    // Botão dourado
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) =>
                                  OnboardingScreen(lang: widget.lang),
                              transitionsBuilder:
                                  (_, anim, __, child) =>
                                      FadeTransition(
                                          opacity: anim, child: child),
                              transitionDuration:
                                  const Duration(milliseconds: 400),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                        ),
                        child: Text(
                          _t('btn'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Center(
                      child: Text(
                        _t('disc'),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.grey),
                      ),
                    ),

                    const SizedBox(height: 24),
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

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.gold.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: AppColors.gold.withOpacity(0.2)),
          ),
          child: Icon(icon, size: 16, color: AppColors.gold),
        ),
        const SizedBox(width: 14),
        Text(text,
            style: const TextStyle(
                fontSize: 14, color: AppColors.whitesoft)),
      ],
    );
  }
}

// ─── ONBOARDING ───────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  final String lang;
  const OnboardingScreen({super.key, required this.lang});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeIn;
  final _nomeCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _nascCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _texts = {
    'pt': {
      'title': 'ANTES DE COMEÇAR',
      'desc': 'Precisamos de algumas informações para personalizar seu resultado.',
      'name': 'Nome completo', 'name_h': 'Como você se chama?',
      'phone': 'Telefone / WhatsApp', 'phone_h': '(305) 000-0000',
      'birth': 'Data de nascimento', 'birth_h': 'MM/DD/AAAA',
      'privacy': 'Suas informações são confidenciais e nunca serão compartilhadas sem sua autorização.',
      'btn': 'CONTINUAR',
      'e_name': 'Digite seu nome',
      'e_phone': 'Digite seu telefone',
      'e_birth': 'Digite sua data de nascimento',
    },
    'es': {
      'title': 'ANTES DE EMPEZAR',
      'desc': 'Necesitamos algunos datos para personalizar tu resultado.',
      'name': 'Nombre completo', 'name_h': '¿Cómo te llamas?',
      'phone': 'Teléfono / WhatsApp', 'phone_h': '(305) 000-0000',
      'birth': 'Fecha de nacimiento', 'birth_h': 'MM/DD/AAAA',
      'privacy': 'Tu información es confidencial y nunca será compartida sin tu autorización.',
      'btn': 'CONTINUAR',
      'e_name': 'Escribe tu nombre',
      'e_phone': 'Escribe tu teléfono',
      'e_birth': 'Escribe tu fecha de nacimiento',
    },
    'en': {
      'title': 'BEFORE WE START',
      'desc': 'We need some basic information to personalize your result.',
      'name': 'Full name', 'name_h': 'What is your name?',
      'phone': 'Phone / WhatsApp', 'phone_h': '(305) 000-0000',
      'birth': 'Date of birth', 'birth_h': 'MM/DD/YYYY',
      'privacy': 'Your information is confidential and will never be shared without your authorization.',
      'btn': 'CONTINUE',
      'e_name': 'Enter your name',
      'e_phone': 'Enter your phone',
      'e_birth': 'Enter your date of birth',
    },
  };

  String _t(String key) =>
      _texts[widget.lang]?[key] ?? _texts['pt']![key]!;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _nomeCtrl.dispose();
    _telCtrl.dispose();
    _nascCtrl.dispose();
    super.dispose();
  }

  void _continuar() {
    if (_formKey.currentState!.validate()) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => QuestionScreen(
            lang: widget.lang,
            nome: _nomeCtrl.text.trim(),
            telefone: _telCtrl.text.trim(),
            nascimento: _nascCtrl.text.trim(),
          ),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: WatermarkBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),

                    const M4LifeLogo(fontSize: 20, showTagline: true),

                    const SizedBox(height: 32),

                    // Linha dourada divisora
                    Container(
                      width: 40,
                      height: 2,
                      color: AppColors.gold,
                    ),

                    const SizedBox(height: 16),

                    Text(_t('title'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.white,
                          letterSpacing: 2,
                        )),

                    const SizedBox(height: 8),

                    Text(_t('desc'),
                        style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.greyLight,
                            height: 1.6)),

                    const SizedBox(height: 32),

                    _Campo(
                      ctrl: _nomeCtrl,
                      label: _t('name'),
                      hint: _t('name_h'),
                      icon: Icons.person_outline,
                      tipo: TextInputType.name,
                      erro: _t('e_name'),
                    ),
                    const SizedBox(height: 16),
                    _Campo(
                      ctrl: _telCtrl,
                      label: _t('phone'),
                      hint: _t('phone_h'),
                      icon: Icons.phone_outlined,
                      tipo: TextInputType.phone,
                      erro: _t('e_phone'),
                    ),
                    const SizedBox(height: 16),
                    _Campo(
                      ctrl: _nascCtrl,
                      label: _t('birth'),
                      hint: _t('birth_h'),
                      icon: Icons.cake_outlined,
                      tipo: TextInputType.datetime,
                      erro: _t('e_birth'),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_outline,
                            size: 12,
                            color: AppColors.gold.withOpacity(0.5)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_t('privacy'),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.grey,
                                  height: 1.5)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _continuar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                        ),
                        child: Text(_t('btn'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            )),
                      ),
                    ),

                    const SizedBox(height: 32),
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

class _Campo extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType tipo;
  final String erro;

  const _Campo({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    required this.tipo,
    required this.erro,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: AppColors.greyLight,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: tipo,
          style: const TextStyle(
              color: AppColors.whiteWarm, fontSize: 15),
          validator: (v) =>
              v == null || v.trim().isEmpty ? erro : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: AppColors.grey, fontSize: 14),
            prefixIcon: Icon(icon,
                size: 18,
                color: AppColors.gold.withOpacity(0.6)),
            filled: true,
            fillColor: AppColors.blackCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                  color: AppColors.gold.withOpacity(0.15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                  color: AppColors.gold.withOpacity(0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(
                  color: AppColors.gold, width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  const BorderSide(color: Color(0xFFE74C3C)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  const BorderSide(color: Color(0xFFE74C3C)),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
