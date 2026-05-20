import 'package:flutter/material.dart';
import 'language_screen.dart';

class LivingBenefitScreen extends StatefulWidget {
  final String lang;
  final VoidCallback onContinue;

  const LivingBenefitScreen({
    super.key,
    required this.lang,
    required this.onContinue,
  });

  @override
  State<LivingBenefitScreen> createState() => _LivingBenefitScreenState();
}

class _LivingBenefitScreenState extends State<LivingBenefitScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeIn;
  int _currentCard = 0;

  final _cards = [
    {
      'pt': {
        'icon': '🏥',
        'title': 'E se você ficasse gravemente doente?',
        'desc': 'Se você for diagnosticado com câncer, infarto ou outra doença grave, seu seguro de vida pode pagar AGORA — sem você precisar morrer.',
        'highlight': 'Isso se chama Benefício em Vida.',
      },
      'es': {
        'icon': '🏥',
        'title': '¿Y si te enfermaras gravemente?',
        'desc': 'Si te diagnostican cáncer, infarto u otra enfermedad grave, tu seguro de vida puede pagar AHORA — sin que tengas que morir.',
        'highlight': 'Esto se llama Beneficio en Vida.',
      },
      'en': {
        'icon': '🏥',
        'title': 'What if you got seriously ill?',
        'desc': 'If you are diagnosed with cancer, heart attack or another serious illness, your life insurance can pay NOW — without you having to die.',
        'highlight': 'This is called a Living Benefit.',
      },
    },
    {
      'pt': {
        'icon': '👨‍👩‍👧',
        'title': 'Proteção para você E sua família',
        'desc': 'Seguro de vida moderno não é só para quando você morre. É para pagar suas contas, manter sua família e dar tempo para você se recuperar.',
        'highlight': 'Você usa o seguro ainda em vida.',
      },
      'es': {
        'icon': '👨‍👩‍👧',
        'title': 'Protección para ti Y tu familia',
        'desc': 'El seguro de vida moderno no es solo para cuando mueres. Es para pagar tus cuentas, mantener a tu familia y darte tiempo para recuperarte.',
        'highlight': 'Usas el seguro aún en vida.',
      },
      'en': {
        'icon': '👨‍👩‍👧',
        'title': 'Protection for you AND your family',
        'desc': 'Modern life insurance is not just for when you die. It is to pay your bills, support your family and give you time to recover.',
        'highlight': 'You use the insurance while still alive.',
      },
    },
    {
      'pt': {
        'icon': '💰',
        'title': 'Quanto você pode receber?',
        'desc': 'Dependendo do seu plano, você pode acessar entre 25% e 100% do valor do seguro em caso de doença grave. Sem burocracia. Sem espera.',
        'highlight': 'Pergunte ao seu consultor sobre essa opção.',
      },
      'es': {
        'icon': '💰',
        'title': '¿Cuánto puedes recibir?',
        'desc': 'Dependiendo de tu plan, puedes acceder entre el 25% y el 100% del valor del seguro en caso de enfermedad grave. Sin burocracia. Sin espera.',
        'highlight': 'Pregúntale a tu consultor sobre esta opción.',
      },
      'en': {
        'icon': '💰',
        'title': 'How much can you receive?',
        'desc': 'Depending on your plan, you can access between 25% and 100% of the insurance value in case of serious illness. No bureaucracy. No waiting.',
        'highlight': 'Ask your consultant about this option.',
      },
    },
  ];

  String _t(Map card, String key) {
    return (card[widget.lang] ?? card['pt'])[key] ?? '';
  }

  String _btnNext() {
    switch (widget.lang) {
      case 'es': return 'Siguiente';
      case 'en': return 'Next';
      default: return 'Próximo';
    }
  }

  String _btnTalk() {
    switch (widget.lang) {
      case 'es': return 'Hablar con consultor ahora';
      case 'en': return 'Talk to consultant now';
      default: return 'Falar com consultor agora';
    }
  }

  String _skip() {
    switch (widget.lang) {
      case 'es': return 'Saltar';
      case 'en': return 'Skip';
      default: return 'Pular';
    }
  }

  String _pageLabel() {
    return '${_currentCard + 1} / ${_cards.length}';
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentCard < _cards.length - 1) {
      _ctrl.reset();
      setState(() => _currentCard++);
      _ctrl.forward();
    } else {
      widget.onContinue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _cards[_currentCard];

    return Scaffold(
      backgroundColor: AppColors.black,
      body: WatermarkBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: AppColors.gold.withOpacity(0.3)),
                        ),
                        child: Text(
                          widget.lang == 'en'
                              ? 'DID YOU KNOW?'
                              : widget.lang == 'es'
                                  ? '¿SABÍAS QUE?'
                                  : 'VOCÊ SABIA?',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.gold,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // Skip
                      GestureDetector(
                        onTap: widget.onContinue,
                        child: Text(
                          _skip(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Emoji
                  Text(
                    _t(card, 'icon'),
                    style: const TextStyle(fontSize: 64),
                  ),

                  const SizedBox(height: 24),

                  // Título
                  Text(
                    _t(card, 'title'),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.white,
                      height: 1.15,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Descrição
                  Text(
                    _t(card, 'desc'),
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.greyLight,
                      height: 1.7,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Highlight dourado
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.gold.withOpacity(0.12),
                          AppColors.gold.withOpacity(0.04),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.gold.withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star,
                            color: AppColors.gold, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _t(card, 'highlight'),
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.gold,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Indicadores de página
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _cards.length,
                      (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _currentCard ? 24 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _currentCard
                              ? AppColors.gold
                              : AppColors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Botão
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentCard < _cards.length - 1
                            ? _btnNext()
                            : _btnTalk(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Disclaimer
                  Center(
                    child: Text(
                      widget.lang == 'en'
                          ? 'Educational content. Not insurance advice.'
                          : widget.lang == 'es'
                              ? 'Contenido educativo. No es asesoría de seguros.'
                              : 'Conteúdo educacional. Não é consultoria de seguros.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.grey.withOpacity(0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
