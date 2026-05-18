import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hitlook/legacy/screens/chat_screen.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';

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

  double _renda = 3000;
  int _anos = 10;
  bool _temDivida = false;
  double _divida = 0;

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
      await FirebaseFirestore.instance.collection('leads').add({
        'agentId': widget.agentId,
        'nome': widget.nome,
        'telefone': widget.telefone,
        'nascimento': widget.nascimento,
        'lang': widget.lang,
        'answers': widget.answers,
        'score': _score,
        'status': 'novo',
        'createdAt': FieldValue.serverTimestamp(),
      });
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

  @override
  void initState() {
    super.initState();
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

  void _abrirChat() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ChatScreen(
          lang: widget.lang,
          answers: widget.answers,
          score: _score,
          nome: widget.nome,
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
  }

  void _abrirWhatsApp() {
    // Aqui vai o link do WhatsApp do agente
    // Por enquanto placeholder
  }

  @override
  Widget build(BuildContext context) {
    final plano = _plano;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: WatermarkBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 28),

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
                      onPressed: _abrirChat,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_t('talk_ana'),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5)),
                          const SizedBox(width: 8),
                          const Icon(Icons.chat_bubble_outline, size: 16),
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
                      onPressed: _abrirWhatsApp,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.white,
                        side: BorderSide(
                            color: AppColors.gold.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Row(
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
