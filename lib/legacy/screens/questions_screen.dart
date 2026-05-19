import 'package:flutter/material.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';
import 'package:hitlook/legacy/screens/result_screen.dart';
import 'package:hitlook/legacy/widgets/public_lead_flow_scaffold.dart';

class QuestionScreen extends StatefulWidget {
  final String lang;
  final String nome;
  final String telefone;
  final String nascimento;
  final String agentId;

  const QuestionScreen({
    super.key,
    required this.lang,
    required this.nome,
    required this.telefone,
    required this.nascimento,
    this.agentId = 'default',
  });

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen>
    with SingleTickerProviderStateMixin {
  int _current = 0;
  final Map<String, dynamic> _answers = {};
  late AnimationController _ctrl;
  late Animation<double> _fade;

  List<Map<String, dynamic>> get _questions {
    final l = widget.lang;
    final data = {
      'pt': [
        {
          'id': 'dependentes',
          'icon': Icons.home_outlined,
          'pergunta': 'Quantas pessoas dependem\nfinanceiramente de você?',
          'sub': 'Filhos, cônjuge ou outros familiares',
          'opcoes': [
            {'label': 'Só eu mesmo', 'valor': 0, 'icon': Icons.person_outline},
            {'label': '1 a 2 pessoas', 'valor': 1, 'icon': Icons.group_outlined},
            {'label': '3 a 4 pessoas', 'valor': 2, 'icon': Icons.groups_outlined},
            {'label': '5 ou mais', 'valor': 3, 'icon': Icons.people_outline},
          ],
        },
        {
          'id': 'renda',
          'icon': Icons.attach_money,
          'pergunta': 'Qual é a sua renda\nmensal aproximada?',
          'sub': 'Isso nos ajuda a calcular sua necessidade',
          'opcoes': [
            {'label': 'Até \$2,000', 'valor': 1, 'icon': Icons.money_outlined},
            {'label': '\$2,000 – \$4,000', 'valor': 2, 'icon': Icons.money_outlined},
            {'label': '\$4,000 – \$7,000', 'valor': 3, 'icon': Icons.money_outlined},
            {'label': 'Acima de \$7,000', 'valor': 4, 'icon': Icons.money_outlined},
          ],
        },
        {
          'id': 'seguro',
          'icon': Icons.shield_outlined,
          'pergunta': 'Você já tem algum\nseguro de vida hoje?',
          'sub': 'Qualquer tipo de cobertura conta',
          'opcoes': [
            {'label': 'Não tenho nenhum', 'valor': 0, 'icon': Icons.close},
            {'label': 'Tenho mas é pouco', 'valor': 1, 'icon': Icons.remove},
            {'label': 'Tenho pelo trabalho', 'valor': 2, 'icon': Icons.work_outline},
            {'label': 'Tenho e estou satisfeito', 'valor': 3, 'icon': Icons.check},
          ],
        },
        {
          'id': 'preocupacao',
          'icon': Icons.favorite_border,
          'pergunta': 'O que mais te preocupa\nse algo acontecer com você?',
          'sub': 'Escolha o que mais se aplica',
          'opcoes': [
            {'label': 'Pagar o aluguel ou hipoteca', 'valor': 'moradia', 'icon': Icons.house_outlined},
            {'label': 'Educação dos filhos', 'valor': 'educacao', 'icon': Icons.school_outlined},
            {'label': 'Dívidas e contas', 'valor': 'dividas', 'icon': Icons.receipt_outlined},
            {'label': 'Futuro da família em geral', 'valor': 'familia', 'icon': Icons.family_restroom},
          ],
        },
        {
          'id': 'momento',
          'icon': Icons.calendar_today_outlined,
          'pergunta': 'Se tivesse uma solução ideal,\nquando você gostaria de ter?',
          'sub': 'Sem compromisso, só para entendermos',
          'opcoes': [
            {'label': 'O quanto antes', 'valor': 'urgente', 'icon': Icons.bolt},
            {'label': 'Nos próximos 30 dias', 'valor': '30dias', 'icon': Icons.calendar_month_outlined},
            {'label': 'Ainda estou pesquisando', 'valor': 'pesquisando', 'icon': Icons.search},
            {'label': 'Só curiosidade por agora', 'valor': 'curioso', 'icon': Icons.visibility_outlined},
          ],
        },
      ],
      'es': [
        {
          'id': 'dependentes',
          'icon': Icons.home_outlined,
          'pergunta': '¿Cuántas personas dependen\nde ti económicamente?',
          'sub': 'Hijos, cónyuge u otros familiares',
          'opcoes': [
            {'label': 'Solo yo', 'valor': 0, 'icon': Icons.person_outline},
            {'label': '1 a 2 personas', 'valor': 1, 'icon': Icons.group_outlined},
            {'label': '3 a 4 personas', 'valor': 2, 'icon': Icons.groups_outlined},
            {'label': '5 o más', 'valor': 3, 'icon': Icons.people_outline},
          ],
        },
        {
          'id': 'renda',
          'icon': Icons.attach_money,
          'pergunta': '¿Cuál es tu ingreso\nmensual aproximado?',
          'sub': 'Esto nos ayuda a calcular tu necesidad',
          'opcoes': [
            {'label': 'Hasta \$2,000', 'valor': 1, 'icon': Icons.money_outlined},
            {'label': '\$2,000 – \$4,000', 'valor': 2, 'icon': Icons.money_outlined},
            {'label': '\$4,000 – \$7,000', 'valor': 3, 'icon': Icons.money_outlined},
            {'label': 'Más de \$7,000', 'valor': 4, 'icon': Icons.money_outlined},
          ],
        },
        {
          'id': 'seguro',
          'icon': Icons.shield_outlined,
          'pergunta': '¿Ya tienes algún\nseguro de vida hoy?',
          'sub': 'Cualquier tipo de cobertura cuenta',
          'opcoes': [
            {'label': 'No tengo ninguno', 'valor': 0, 'icon': Icons.close},
            {'label': 'Tengo pero es poco', 'valor': 1, 'icon': Icons.remove},
            {'label': 'Tengo por el trabajo', 'valor': 2, 'icon': Icons.work_outline},
            {'label': 'Tengo y estoy satisfecho', 'valor': 3, 'icon': Icons.check},
          ],
        },
        {
          'id': 'preocupacao',
          'icon': Icons.favorite_border,
          'pergunta': '¿Qué te preocupa más\nsi algo te pasara?',
          'sub': 'Elige lo que más aplica',
          'opcoes': [
            {'label': 'Pagar el alquiler o hipoteca', 'valor': 'moradia', 'icon': Icons.house_outlined},
            {'label': 'Educación de los hijos', 'valor': 'educacao', 'icon': Icons.school_outlined},
            {'label': 'Deudas y facturas', 'valor': 'dividas', 'icon': Icons.receipt_outlined},
            {'label': 'Futuro de la familia en general', 'valor': 'familia', 'icon': Icons.family_restroom},
          ],
        },
        {
          'id': 'momento',
          'icon': Icons.calendar_today_outlined,
          'pergunta': 'Si tuvieras una solución ideal,\n¿cuándo te gustaría tenerla?',
          'sub': 'Sin compromiso, solo para entender',
          'opcoes': [
            {'label': 'Lo antes posible', 'valor': 'urgente', 'icon': Icons.bolt},
            {'label': 'En los próximos 30 días', 'valor': '30dias', 'icon': Icons.calendar_month_outlined},
            {'label': 'Aún estoy investigando', 'valor': 'pesquisando', 'icon': Icons.search},
            {'label': 'Solo curiosidad por ahora', 'valor': 'curioso', 'icon': Icons.visibility_outlined},
          ],
        },
      ],
      'en': [
        {
          'id': 'dependentes',
          'icon': Icons.home_outlined,
          'pergunta': 'How many people depend\non you financially?',
          'sub': 'Children, spouse or other family members',
          'opcoes': [
            {'label': 'Just me', 'valor': 0, 'icon': Icons.person_outline},
            {'label': '1 to 2 people', 'valor': 1, 'icon': Icons.group_outlined},
            {'label': '3 to 4 people', 'valor': 2, 'icon': Icons.groups_outlined},
            {'label': '5 or more', 'valor': 3, 'icon': Icons.people_outline},
          ],
        },
        {
          'id': 'renda',
          'icon': Icons.attach_money,
          'pergunta': 'What is your approximate\nmonthly income?',
          'sub': 'This helps us calculate your need',
          'opcoes': [
            {'label': 'Up to \$2,000', 'valor': 1, 'icon': Icons.money_outlined},
            {'label': '\$2,000 – \$4,000', 'valor': 2, 'icon': Icons.money_outlined},
            {'label': '\$4,000 – \$7,000', 'valor': 3, 'icon': Icons.money_outlined},
            {'label': 'Above \$7,000', 'valor': 4, 'icon': Icons.money_outlined},
          ],
        },
        {
          'id': 'seguro',
          'icon': Icons.shield_outlined,
          'pergunta': 'Do you have any\nlife insurance today?',
          'sub': 'Any type of coverage counts',
          'opcoes': [
            {'label': 'I have none', 'valor': 0, 'icon': Icons.close},
            {'label': 'I have some but not enough', 'valor': 1, 'icon': Icons.remove},
            {'label': 'I have it through work', 'valor': 2, 'icon': Icons.work_outline},
            {'label': 'I have it and I\'m satisfied', 'valor': 3, 'icon': Icons.check},
          ],
        },
        {
          'id': 'preocupacao',
          'icon': Icons.favorite_border,
          'pergunta': 'What worries you most\nif something happened to you?',
          'sub': 'Choose what applies most',
          'opcoes': [
            {'label': 'Paying rent or mortgage', 'valor': 'moradia', 'icon': Icons.house_outlined},
            {'label': 'Children\'s education', 'valor': 'educacao', 'icon': Icons.school_outlined},
            {'label': 'Debts and bills', 'valor': 'dividas', 'icon': Icons.receipt_outlined},
            {'label': 'Family\'s future in general', 'valor': 'familia', 'icon': Icons.family_restroom},
          ],
        },
        {
          'id': 'momento',
          'icon': Icons.calendar_today_outlined,
          'pergunta': 'If you had an ideal solution,\nwhen would you like to have it?',
          'sub': 'No commitment, just to understand',
          'opcoes': [
            {'label': 'As soon as possible', 'valor': 'urgente', 'icon': Icons.bolt},
            {'label': 'In the next 30 days', 'valor': '30dias', 'icon': Icons.calendar_month_outlined},
            {'label': 'I\'m still researching', 'valor': 'pesquisando', 'icon': Icons.search},
            {'label': 'Just curious for now', 'valor': 'curioso', 'icon': Icons.visibility_outlined},
          ],
        },
      ],
    };
    return List<Map<String, dynamic>>.from(data[l] ?? data['pt']!);
  }

  String _greeting() {
    final nome = widget.nome.split(' ').first;
    switch (widget.lang) {
      case 'es': return '¡Hola, $nome! 👋';
      case 'en': return 'Hi, $nome! 👋';
      default: return 'Olá, $nome! 👋';
    }
  }

  String _confidential() {
    switch (widget.lang) {
      case 'es': return 'Tus respuestas son confidenciales';
      case 'en': return 'Your answers are confidential';
      default: return 'Suas respostas são confidenciais';
    }
  }

  void _responder(dynamic valor) {
    setState(() {
      _answers[_questions[_current]['id']] = valor;
    });
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      if (_current < _questions.length - 1) {
        setState(() => _current++);
        _ctrl.reset();
        _ctrl.forward();
      } else {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => ResultScreen(
              lang: widget.lang,
              answers: _answers,
              nome: widget.nome,
              telefone: widget.telefone,
              nascimento: widget.nascimento,
              agentId: widget.agentId,
            ),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_current];
    final progress = (_current + 1) / _questions.length;

    return PublicLeadFlowScaffold(
      lang: widget.lang,
      child: WatermarkBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Header
                  Row(
                    children: [
                      if (_current > 0)
                        GestureDetector(
                          onTap: () {
                            setState(() => _current--);
                            _ctrl.reset();
                            _ctrl.forward();
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.blackCard,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.gold.withOpacity(0.2),
                              ),
                            ),
                            child: Icon(Icons.arrow_back,
                                size: 16, color: AppColors.gold),
                          ),
                        )
                      else
                        const SizedBox(width: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${_current + 1} / ${_questions.length}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.gold.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor:
                                    AppColors.gold.withOpacity(0.1),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        AppColors.gold),
                                minHeight: 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Saudação
                  Text(
                    _greeting(),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.gold.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Ícone
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.gold.withOpacity(0.2),
                      ),
                    ),
                    child: Icon(q['icon'] as IconData,
                        size: 22, color: AppColors.gold),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    q['pergunta'],
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.white,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    q['sub'],
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.greyLight),
                  ),

                  const SizedBox(height: 24),

                  Expanded(
                    child: ListView.separated(
                      itemCount: (q['opcoes'] as List).length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final op = (q['opcoes'] as List)[i];
                        return _OptionCard(
                          label: op['label'],
                          icon: op['icon'] as IconData,
                          onTap: () => _responder(op['valor']),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  Center(
                    child: Text(
                      _confidential(),
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.grey.withOpacity(0.5)),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OptionCard(
      {required this.label, required this.icon, required this.onTap});

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.gold.withOpacity(0.1)
              : AppColors.blackCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _pressed
                ? AppColors.gold
                : AppColors.gold.withOpacity(0.15),
            width: _pressed ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _pressed
                    ? AppColors.gold.withOpacity(0.15)
                    : AppColors.gold.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.icon,
                  size: 17, color: AppColors.gold),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _pressed
                      ? AppColors.gold
                      : AppColors.whitesoft,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: AppColors.gold.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}
