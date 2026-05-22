import 'package:flutter/material.dart';
import 'package:hitlook/core/utils/whatsapp_utils.dart';
import 'living_benefit_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hitlook/legacy/screens/agent_profile.dart';
import 'package:hitlook/legacy/screens/chat_screen.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';
import 'package:hitlook/legacy/widgets/flow_ux.dart';
import 'package:hitlook/legacy/widgets/public_lead_flow_scaffold.dart';

class ResultScreen extends StatefulWidget {
  final String lang;
  final Map<String, dynamic> answers;
  final String nome;
  final String telefone;
  final String nascimento;
  final String agentId;

  const ResultScreen({
    super.key,
    required this.lang,
    required this.answers,
    required this.nome,
    required this.telefone,
    required this.nascimento,
    this.agentId = 'default',
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeIn;
  late Animation<double> _scoreAnim;
  String _consultantPhone = kDefaultConsultantWhatsApp;

  double _renda = 3000;
  int _anos = 10;
  bool _temDivida = false;
  double _divida = 0;
  bool _whatsAppLoading = false;
  bool _chatLoading = false;

  int get _score {
    int s = 0;
    final dep = widget.answers['dependentes'] ?? 0;
    final renda = widget.answers['renda'] ?? 1;
    final seguro = widget.answers['seguro'] ?? 0;
    if (dep == 0) s += 30;
    if (dep == 1) s += 15;
    if (seguro == 3) s += 40;
    if (seguro == 2) s += 25;
    if (seguro == 1) s += 10;
    if (renda >= 3) s += 20;
    if (renda == 2) s += 10;
    return s.clamp(5, 95);
  }

  Color get _scoreColor {
    if (_score >= 70) return const Color(0xFF2ECC71);
    if (_score >= 40) return const Color(0xFFF39C12);
    return const Color(0xFFE74C3C);
  }

  String get _scoreLabel {
    final l = widget.lang;
    if (_score >= 70) {
      return l == 'en' ? 'Well Protected' : 'Bem Protegido';
    }
    if (_score >= 40) {
      return l == 'en' ? 'Partially Protected' : l == 'es' ? 'Parcialmente Protegido' : 'Parcialmente Protegido';
    }
    return 'Vulnerable';
  }

  Map<String, dynamic> get _plano {
    final dep = widget.answers['dependentes'] ?? 0;
    final renda = widget.answers['renda'] ?? 1;
    final seguro = widget.answers['seguro'] ?? 0;
    final l = widget.lang;

    if (dep == 0 && seguro >= 2) {
      return {
        'nome': l == 'en' ? 'Term Life — Basic' : 'Term Life — Básico',
        'desc': l == 'en'
            ? 'Simple coverage to protect your assets and ensure personal peace of mind.'
            : l == 'es'
                ? 'Cobertura simple para proteger tu patrimonio.'
                : 'Cobertura simples para proteger seu patrimônio.',
        'cobertura': '\$100,000 – \$250,000',
        'custo': '\$15 – \$30/mo',
        'urgencia': l == 'en' ? 'Low' : l == 'es' ? 'Baja' : 'Baixa',
        'corUrgencia': const Color(0xFF2ECC71),
      };
    }
    if (dep >= 2 && renda >= 3) {
      return {
        'nome': l == 'en' ? 'Whole Life — Family' : l == 'es' ? 'Whole Life — Familia' : 'Whole Life — Família',
        'desc': l == 'en'
            ? 'Permanent protection with living benefits. Ideal for families who want to leave a legacy.'
            : l == 'es'
                ? 'Protección permanente con beneficio en vida. Ideal para familias.'
                : 'Proteção permanente com benefício em vida. Ideal para famílias.',
        'cobertura': '\$500,000 – \$1,000,000',
        'custo': '\$80 – \$200/mo',
        'urgencia': l == 'en' ? 'High' : l == 'es' ? 'Alta' : 'Alta',
        'corUrgencia': const Color(0xFFE74C3C),
      };
    }
    if (dep >= 1 && renda >= 2) {
      return {
        'nome': l == 'en' ? 'Term Life — Family' : l == 'es' ? 'Term Life — Familia' : 'Term Life — Família',
        'desc': l == 'en'
            ? 'Solid term life coverage. Protects your family during the most critical period.'
            : l == 'es'
                ? 'Cobertura a término sólida. Protege a tu familia en el período más crítico.'
                : 'Cobertura termo sólida. Protege sua família pelo período mais crítico.',
        'cobertura': '\$250,000 – \$500,000',
        'custo': '\$25 – \$60/mo',
        'urgencia': l == 'en' ? 'High' : 'Alta',
        'corUrgencia': const Color(0xFFE74C3C),
      };
    }
    return {
      'nome': l == 'en' ? 'Term Life — Essential' : l == 'es' ? 'Term Life — Esencial' : 'Term Life — Essencial',
      'desc': l == 'en'
          ? 'Essential coverage at an affordable cost. The first step to protect those you love.'
          : l == 'es'
              ? 'Cobertura esencial a precio accesible.'
              : 'Cobertura essencial com custo acessível.',
      'cobertura': '\$150,000 – \$300,000',
      'custo': '\$20 – \$40/mo',
      'urgencia': l == 'en' ? 'Medium' : l == 'es' ? 'Media' : 'Média',
      'corUrgencia': const Color(0xFFF39C12),
    };
  }

  Future<void> _saveLead() async {
    try {
      final ownerUid = await AgentProvider.resolveOwnerUid(widget.agentId);
      final agent = await AgentProvider.loadAgent(widget.agentId);

      final legacyPayload = {
        'agentId': ownerUid,
        'nome': widget.nome,
        'telefone': widget.telefone,
        'nascimento': widget.nascimento,
        'lang': widget.lang,
        'answers': widget.answers,
        'score': _score,
        'status': 'novo',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('leads').add(legacyPayload);

      if (agent.hasSaaSContext) {
        final companyId = agent.companyId!;
        final sellerId = agent.sellerId!;
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('leads')
            .add({
          'companyId': companyId,
          'sellerId': sellerId,
          'agentId': ownerUid,
          'nome': widget.nome,
          'telefone': widget.telefone,
          'prospectName': widget.nome,
          'prospectPhone': widget.telefone,
          'nascimento': widget.nascimento,
          'lang': widget.lang,
          'locale': widget.lang,
          'answers': widget.answers,
          'score': _score,
          'status': 'novo',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // ignora erro silenciosamente
    }
  }

  double get _total => (_renda * 12 * _anos) + (_temDivida ? _divida : 0);

  String _fmt(double v) {
    if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }

  String _t(String key) {
    final l = widget.lang;
    final m = {
      'result_label': {'pt': 'SEU RESULTADO', 'es': 'TU RESULTADO', 'en': 'YOUR RESULT'},
      'result_title': {'pt': 'Nível de Proteção\nFamiliar', 'es': 'Nivel de Protección\nFamiliar', 'en': 'Family Protection\nLevel'},
      'vulnerable': {'pt': 'Vulnerável', 'es': 'Vulnerable', 'en': 'Vulnerable'},
      'protected': {'pt': 'Protegido', 'es': 'Protegido', 'en': 'Protected'},
      'plan_label': {'pt': 'PLANO RECOMENDADO', 'es': 'PLAN RECOMENDADO', 'en': 'RECOMMENDED PLAN'},
      'urgency': {'pt': 'Urgência', 'es': 'Urgencia', 'en': 'Urgency'},
      'coverage': {'pt': 'Cobertura estimada', 'es': 'Cobertura estimada', 'en': 'Estimated coverage'},
      'cost': {'pt': 'Custo aprox.', 'es': 'Costo aprox.', 'en': 'Approx. cost'},
      'disclaimer': {'pt': '* Valores educacionais. Consultor calculará o exato.', 'es': '* Valores educativos. El consultor calculará el exacto.', 'en': '* Educational values. Consultant will calculate the exact amount.'},
      'calc_label': {'pt': 'CALCULADORA FAMILIAR', 'es': 'CALCULADORA FAMILIAR', 'en': 'FAMILY CALCULATOR'},
      'calc_title': {'pt': 'Quanto sua família precisaria?', 'es': '¿Cuánto necesitaría tu familia?', 'en': 'How much would your family need?'},
      'calc_desc': {'pt': 'O plano recomendado acima mostra a cobertura ideal. A calculadora abaixo mostra quanto sua família precisaria para manter o padrão de vida.', 'es': 'El plan recomendado muestra la cobertura ideal. La calculadora muestra cuánto necesitaría tu familia para mantener su nivel de vida.', 'en': 'The recommended plan shows ideal coverage. The calculator shows how much your family would need to maintain their lifestyle.'},
      'income': {'pt': 'Renda mensal', 'es': 'Ingreso mensual', 'en': 'Monthly income'},
      'years': {'pt': 'Anos de proteção', 'es': 'Años de protección', 'en': 'Years of protection'},
      'debt': {'pt': 'Tem dívidas?', 'es': '¿Tienes deudas?', 'en': 'Have debts?'},
      'debt_sub': {'pt': 'Hipoteca, empréstimos, etc.', 'es': 'Hipoteca, préstamos, etc.', 'en': 'Mortgage, loans, etc.'},
      'debt_total': {'pt': 'Total das dívidas', 'es': 'Total de deudas', 'en': 'Total debts'},
      'family_needs': {'pt': 'Sua família precisaria de', 'es': 'Tu familia necesitaría', 'en': 'Your family would need'},
      'to_maintain': {'pt': 'para manter o padrão de vida por', 'es': 'para mantener el nivel de vida por', 'en': 'to maintain lifestyle for'},
      'years_label': {'pt': 'anos', 'es': 'años', 'en': 'years'},
      'ana_title': {'pt': 'Ficou com dúvidas?', 'es': '¿Tienes dudas?', 'en': 'Have questions?'},
      'ana_sub': {'pt': 'A Ana responde agora, na hora.', 'es': 'Ana responde ahora, al instante.', 'en': 'Ana answers now, instantly.'},
      'ask': {'pt': 'Perguntar', 'es': 'Preguntar', 'en': 'Ask'},
      'talk_ana': {'pt': 'Falar com a Ana agora', 'es': 'Hablar con Ana ahora', 'en': 'Talk to Ana now'},
      'talk_agent': {'pt': 'Falar com um consultor', 'es': 'Hablar con un consultor', 'en': 'Talk to a consultant'},
      'redo': {'pt': 'Refazer o teste', 'es': 'Repetir el test', 'en': 'Redo the test'},
      'edu_disc': {'pt': 'Ferramenta educacional. Não constitui aconselhamento de seguros. Consulte um agente licenciado.', 'es': 'Herramienta educativa. No constituye asesoramiento de seguros. Consulte un agente licenciado.', 'en': 'Educational tool only. Does not constitute insurance advice. Consult a licensed agent.'},
    };
    return (m[key] ?? {})[l] ?? (m[key] ?? {})['pt'] ?? key;
  }

  Future<void> _preloadConsultantPhone() async {
    if (widget.agentId.isEmpty || widget.agentId == 'default') return;

    try {
      final agent = await AgentProvider.loadAgent(widget.agentId);
      final raw = agent.whatsapp.trim();
      if (raw.isNotEmpty && normalizeWhatsAppNumber(raw).isNotEmpty) {
        if (mounted) setState(() => _consultantPhone = raw);
      }
    } catch (_) {
      // Keep default Renan number.
    }
  }

  @override
  void initState() {
    super.initState();
    _preloadConsultantPhone();
    _saveLead();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.4, curve: Curves.easeIn),
      ),
    );
    _scoreAnim = Tween<double>(begin: 0, end: _score / 100).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.3, 1, curve: Curves.easeOut),
      ),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _abrirChat() async {
    if (_chatLoading) return;
    setState(() => _chatLoading = true);
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ChatScreen(
          lang: widget.lang,
          answers: widget.answers,
          score: _score,
          nome: widget.nome,
          agentId: widget.agentId,
        ),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
    if (mounted) setState(() => _chatLoading = false);
  }

  /// Sync tap handler — no [setState] before launch (iOS Safari exige gesto do usuário).
  void _abrirWhatsApp() {
    if (_whatsAppLoading) return;

    final phone = _consultantPhone.trim().isNotEmpty
        ? _consultantPhone
        : kDefaultConsultantWhatsApp;

    if (normalizeWhatsAppNumber(phone).isEmpty) {
      _mostrarErroWhatsApp();
      return;
    }

    final msg = buildLeadWhatsAppMessage(lang: widget.lang, score: _score);

    // Dispara launchUrl antes de setState (gesto do usuário no iOS Safari).
    final openedFuture = openWhatsApp(phone: phone, message: msg);
    setState(() => _whatsAppLoading = true);

    openedFuture.then((opened) {
      if (!opened && mounted) _mostrarErroWhatsApp();
    }).catchError((_) {
      if (mounted) _mostrarErroWhatsApp();
    }).whenComplete(() {
      if (mounted) setState(() => _whatsAppLoading = false);
    });
  }

  void _mostrarErroWhatsApp() {
    if (!mounted) return;
    final l = widget.lang;
    final msg = l == 'en'
        ? 'Consultant temporarily unavailable. Please try again later.'
        : l == 'es'
            ? 'Consultor temporalmente no disponible. Inténtalo más tarde.'
            : 'Consultor temporariamente indisponível. Tente novamente.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.blackCard,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plano = _plano;

    return FlowExitGuard(
      lang: widget.lang,
      child: PublicLeadFlowScaffold(
        lang: widget.lang,
        child: WatermarkBackground(
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const FlowBackButton(),
                    const SizedBox(height: 16),

                    const M4LifeLogo(fontSize: 18, showTagline: false),

                  const SizedBox(height: 24),

                  // ── SCORE ──────────────────────
                  Row(
                    children: [
                      Container(width: 3, height: 16, color: AppColors.gold),
                      const SizedBox(width: 8),
                      Text(_t('result_label'),
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.gold,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(_t('result_title'),
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.white,
                          height: 1.2)),

                  const SizedBox(height: 20),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.blackCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.gold.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _scoreAnim,
                          builder: (_, __) => Text(
                            '${(_scoreAnim.value * 100).toInt()}%',
                            style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                                color: _scoreColor,
                                height: 1),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(_scoreLabel,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _scoreColor,
                                letterSpacing: 1)),
                        const SizedBox(height: 18),
                        AnimatedBuilder(
                          animation: _scoreAnim,
                          builder: (_, __) => ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _scoreAnim.value,
                              backgroundColor:
                                  AppColors.gold.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  _scoreColor),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_t('vulnerable'),
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.grey)),
                            Text(_t('protected'),
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── PLANO ──────────────────────
                  Row(
                    children: [
                      Container(width: 3, height: 16, color: AppColors.gold),
                      const SizedBox(width: 8),
                      Text(_t('plan_label'),
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.gold,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.gold.withOpacity(0.1),
                          AppColors.gold.withOpacity(0.03),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.gold.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.gold.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.shield_outlined,
                                  size: 20, color: AppColors.gold),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(plano['nome'],
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.white)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (plano['corUrgencia']
                                              as Color)
                                          .withOpacity(0.15),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${_t('urgency')}: ${plano['urgencia']}',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color:
                                              plano['corUrgencia'] as Color,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(plano['desc'],
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.whitesoft,
                                height: 1.55)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _InfoBox(
                                label: _t('coverage'),
                                value: plano['cobertura'],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _InfoBox(
                                label: _t('cost'),
                                value: plano['custo'],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(_t('disclaimer'),
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.grey,
                                height: 1.5)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  _LivingBenefitCards(lang: widget.lang),

                  const SizedBox(height: 24),

                  // ── CALCULADORA ────────────────
                  Row(
                    children: [
                      Container(width: 3, height: 16, color: AppColors.gold),
                      const SizedBox(width: 8),
                      Text(_t('calc_label'),
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.gold,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(_t('calc_title'),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white)),

                  const SizedBox(height: 4),

                  Text(_t('calc_desc'),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.greyLight)),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.blackCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.gold.withOpacity(0.15)),
                    ),
                    child: Column(
                      children: [
                        _SliderItem(
                          label: _t('income'),
                          value: _fmt(_renda),
                          sliderVal: _renda,
                          min: 500,
                          max: 15000,
                          divisions: 29,
                          onChanged: (v) =>
                              setState(() => _renda = v),
                        ),
                        const SizedBox(height: 18),
                        _SliderItem(
                          label: _t('years'),
                          value: '$_anos ${_t('years_label')}',
                          sliderVal: _anos.toDouble(),
                          min: 5,
                          max: 30,
                          divisions: 25,
                          onChanged: (v) =>
                              setState(() => _anos = v.toInt()),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(_t('debt'),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.whitesoft,
                                          fontWeight: FontWeight.w500)),
                                  Text(_t('debt_sub'),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.grey)),
                                ],
                              ),
                            ),
                            Switch(
                              value: _temDivida,
                              onChanged: (v) =>
                                  setState(() => _temDivida = v),
                              activeColor: AppColors.gold,
                            ),
                          ],
                        ),
                        if (_temDivida) ...[
                          const SizedBox(height: 16),
                          _SliderItem(
                            label: _t('debt_total'),
                            value: _fmt(_divida),
                            sliderVal: _divida,
                            min: 0,
                            max: 500000,
                            divisions: 50,
                            onChanged: (v) =>
                                setState(() => _divida = v),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.black,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.gold.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Text(_t('family_needs'),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.grey)),
                              const SizedBox(height: 6),
                              Text(
                                _fmt(_total),
                                style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.gold,
                                    height: 1),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_t('to_maintain')} $_anos ${_t('years_label')}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── BOTÃO FALAR COM ANA ────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _chatLoading ? null : _abrirChat,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: _chatLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.black,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_t('talk_ana'),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5)),
                                const SizedBox(width: 8),
                                const Icon(Icons.chat_bubble_outline,
                                    size: 16),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── BOTÃO FALAR COM CONSULTOR ──
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed:
                          _whatsAppLoading ? null : _abrirWhatsApp,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.white,
                        side: BorderSide(
                            color: AppColors.gold.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _whatsAppLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.gold,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.phone_outlined,
                                    size: 16, color: AppColors.gold),
                                const SizedBox(width: 8),
                                Text(_t('talk_agent'),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.white)),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── REFAZER ────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: () =>
                          Navigator.popUntil(context, (r) => r.isFirst),
                      child: Text(_t('redo'),
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.greyLight)),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Center(
                    child: Text(_t('edu_disc'),
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.grey.withOpacity(0.6)),
                        textAlign: TextAlign.center),
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

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;

  const _InfoBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.grey)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold)),
        ],
      ),
    );
  }
}

class _SliderItem extends StatelessWidget {
  final String label;
  final String value;
  final double sliderVal;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderItem({
    required this.label,
    required this.value,
    required this.sliderVal,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.whitesoft,
                    fontWeight: FontWeight.w500)),
            Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.gold,
            inactiveTrackColor: AppColors.gold.withOpacity(0.15),
            thumbColor: AppColors.gold,
            overlayColor: AppColors.gold.withOpacity(0.1),
            trackHeight: 3,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: sliderVal.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ─── LIVING BENEFIT CARDS ─────────────────────────────────
class _LivingBenefitCards extends StatefulWidget {
  final String lang;
  const _LivingBenefitCards({required this.lang});

  @override
  State<_LivingBenefitCards> createState() => _LivingBenefitCardsState();
}

class _LivingBenefitCardsState extends State<_LivingBenefitCards> {
  int _current = 0;

  final _cards = [
    {
      'pt': {
        'icon': '🏥',
        'title': 'Você sabia disso?',
        'desc': 'Se você for diagnosticado com uma doença grave como câncer ou infarto, seu seguro pode pagar AGORA — sem você precisar morrer.',
        'highlight': 'Isso se chama Benefício em Vida.',
      },
      'es': {
        'icon': '🏥',
        'title': '¿Sabías esto?',
        'desc': 'Si te diagnostican una enfermedad grave como cáncer o infarto, tu seguro puede pagar AHORA — sin que tengas que morir.',
        'highlight': 'Esto se llama Beneficio en Vida.',
      },
      'en': {
        'icon': '🏥',
        'title': 'Did you know this?',
        'desc': 'If you are diagnosed with a serious illness like cancer or heart attack, your insurance can pay NOW — without you having to die.',
        'highlight': 'This is called a Living Benefit.',
      },
    },
    {
      'pt': {
        'icon': '👨‍👩‍👧',
        'title': 'Proteção para você E sua família',
        'desc': 'Seguro moderno não é só para quando você morre. É para pagar suas contas e manter sua família enquanto você se recupera.',
        'highlight': 'Você usa o seguro ainda em vida.',
      },
      'es': {
        'icon': '👨‍👩‍👧',
        'title': 'Protección para ti Y tu familia',
        'desc': 'El seguro moderno no es solo para cuando mueres. Es para pagar tus cuentas y mantener a tu familia mientras te recuperas.',
        'highlight': 'Usas el seguro aún en vida.',
      },
      'en': {
        'icon': '👨‍👩‍👧',
        'title': 'Protection for you AND your family',
        'desc': 'Modern insurance is not just for when you die. It pays your bills and supports your family while you recover.',
        'highlight': 'You use the insurance while still alive.',
      },
    },
    {
      'pt': {
        'icon': '💬',
        'title': 'Pergunte ao seu consultor',
        'desc': 'Nem todos os planos têm esse benefício. Mas existem opções acessíveis que incluem cobertura em vida. Seu consultor pode mostrar as opções.',
        'highlight': 'Clique abaixo e pergunte sobre o Benefício em Vida.',
      },
      'es': {
        'icon': '💬',
        'title': 'Pregúntale a tu consultor',
        'desc': 'No todos los planes tienen este beneficio. Pero hay opciones accesibles que incluyen cobertura en vida. Tu consultor puede mostrarte las opciones.',
        'highlight': 'Haz clic abajo y pregunta sobre el Beneficio en Vida.',
      },
      'en': {
        'icon': '💬',
        'title': 'Ask your consultant',
        'desc': 'Not all plans have this benefit. But there are affordable options that include living coverage. Your consultant can show you the options.',
        'highlight': 'Click below and ask about the Living Benefit.',
      },
    },
  ];

  String _t(Map card, String key) =>
      (card[widget.lang] ?? card['pt'])[key] ?? '';

  String _next() {
    switch (widget.lang) {
      case 'es': return 'Siguiente';
      case 'en': return 'Next';
      default: return 'Próximo';
    }
  }

  String _understand() {
    switch (widget.lang) {
      case 'es': return 'Entendido';
      case 'en': return 'Got it';
      default: return 'Entendido';
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _cards[_current];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Container(width: 3, height: 16, color: AppColors.gold),
            const SizedBox(width: 8),
            Text(
              widget.lang == 'en'
                  ? 'LIVING BENEFIT'
                  : widget.lang == 'es'
                      ? 'BENEFICIO EN VIDA'
                      : 'BENEFÍCIO EM VIDA',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.gold,
                letterSpacing: 3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Card
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Container(
            key: ValueKey(_current),
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.blackCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.gold.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _t(card, 'icon'),
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _t(card, 'title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Text(
                  _t(card, 'desc'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.greyLight,
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.gold.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star,
                          color: AppColors.gold, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _t(card, 'highlight'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.gold,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Indicadores + botão
                Row(
                  children: [
                    // Dots
                    Row(
                      children: List.generate(
                        _cards.length,
                        (i) => Container(
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _current ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _current
                                ? AppColors.gold
                                : AppColors.grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Botão next/entendido
                    GestureDetector(
                      onTap: () {
                        if (_current < _cards.length - 1) {
                          setState(() => _current++);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _current < _cards.length - 1
                              ? AppColors.gold.withOpacity(0.1)
                              : AppColors.gold,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.gold.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _current < _cards.length - 1
                                  ? _next()
                                  : _understand(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _current < _cards.length - 1
                                    ? AppColors.gold
                                    : AppColors.black,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _current < _cards.length - 1
                                  ? Icons.arrow_forward
                                  : Icons.check,
                              size: 13,
                              color: _current < _cards.length - 1
                                  ? AppColors.gold
                                  : AppColors.black,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
