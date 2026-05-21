import 'package:flutter/material.dart';
import 'package:hitlook/core/config/ana_proxy_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hitlook/legacy/screens/language_screen.dart';
import 'package:hitlook/legacy/widgets/public_lead_flow_scaffold.dart';

class ChatScreen extends StatefulWidget {
  final String lang;
  final Map<String, dynamic> answers;
  final int score;
  final String nome;
  final String agentId;

  const ChatScreen({
    super.key,
    required this.lang,
    required this.answers,
    required this.score,
    required this.nome,
    this.agentId = 'default',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _loading = false;

  String get _systemPrompt {
    final l = widget.lang;
    final nome = widget.nome.split(' ').first;
    final lang = l == 'en' ? 'English' : l == 'es' ? 'Spanish' : 'Brazilian Portuguese';

    final closing = lang == 'en'
        ? 'For what makes sense for your specific situation, always speak with a licensed M4LIFE consultant.'
        : lang == 'es'
            ? 'Para lo que tiene sentido para tu situación específica, siempre habla con un consultor licenciado de M4LIFE.'
            : 'Para o que faz sentido para sua situação específica, fale sempre com um consultor licenciado da M4LIFE.';

    return '''
You are Ana, a friendly financial education assistant for M4LIFE USA.
You provide GENERAL financial education only — NOT insurance advice.

ALWAYS respond in $lang.
Be warm, concise — maximum 2 short paragraphs per response.

CLIENT: $nome

CRITICAL RULES — NEVER VIOLATE:
- You are a GENERAL FINANCIAL EDUCATION tool only
- NEVER recommend any specific insurance product, plan, or insurer
- NEVER give premium estimates or coverage amounts for this person
- NEVER say anything that could be interpreted as insurance solicitation
- NEVER promise approval or coverage
- ALWAYS end every response with: "$closing"
- If asked about specific products, plans or prices, say you cannot provide that and redirect to the licensed consultant
- Never say you are an AI — you are Ana, financial education assistant

YOU CAN DISCUSS (general education only):
- General concepts of financial protection and family planning
- General difference between types of life insurance (conceptual only)
- General importance of having financial protection
- How families plan for the future
- General financial wellness concepts

YOU CANNOT:
- Recommend any specific product or insurer
- Give any price estimates
- Give personalized insurance advice
- Make any statements that could be interpreted as selling insurance
''';
  }

  String _greeting() {
    final nome = widget.nome.split(' ').first;
    switch (widget.lang) {
      case 'es':
        return '¡Hola $nome! Vi tu resultado — ${widget.score}% de protección. ¿Tienes alguna pregunta sobre cómo mejorar tu cobertura?';
      case 'en':
        return 'Hi $nome! I saw your result — ${widget.score}% protection level. Do you have any questions about improving your coverage?';
      default:
        return 'Olá $nome! Vi seu resultado — ${widget.score}% de proteção. Tem alguma dúvida sobre como melhorar sua cobertura?';
    }
  }

  List<String> get _suggestions {
    switch (widget.lang) {
      case 'es':
        return [
          '¿Qué es el beneficio en vida?',
          'Term life vs Whole life',
          '¿Cuánto cuesta en promedio?',
          'Tengo una condición preexistente',
        ];
      case 'en':
        return [
          'What is a living benefit?',
          'Term life vs Whole life',
          'How much does it cost on average?',
          'I have a pre-existing condition',
        ];
      default:
        return [
          'O que é benefício em vida?',
          'Term life vs Whole life',
          'Quanto custa em média?',
          'Tenho pré-existência',
        ];
    }
  }

  String _onlineLabel() {
    switch (widget.lang) {
      case 'es': return 'Assistente M4LIFE • En línea';
      case 'en': return 'M4LIFE Assistant • Online';
      default: return 'Assistente M4LIFE • Online';
    }
  }

  String _hintText() {
    switch (widget.lang) {
      case 'es': return 'Pregúntale a Ana...';
      case 'en': return 'Ask Ana...';
      default: return 'Pergunte à Ana...';
    }
  }

  String _consultantLabel() {
    switch (widget.lang) {
      case 'es': return 'Consultor';
      case 'en': return 'Consultant';
      default: return 'Consultor';
    }
  }

  @override
  void initState() {
    super.initState();
    _messages.add({'role': 'assistant', 'content': _greeting()});
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<String> _callAPI(String message) async {
    try {
      final msgs = <Map<String, String>>[];
      for (final m in _messages) {
        msgs.add({'role': m['role']!, 'content': m['content']!});
      }
      msgs.add({'role': 'user', 'content': message});

      final response = await http.post(
        Uri.parse(AnaProxyConfig.messagesUrl),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 600,
          'system': _systemPrompt,
          'messages': msgs,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'] ?? '...';
      }
      return widget.lang == 'en'
          ? 'Sorry, technical issue. Please try again.'
          : widget.lang == 'es'
              ? 'Lo siento, problema técnico. Intenta de nuevo.'
              : 'Desculpe, problema técnico. Tente novamente.';
    } catch (e) {
      return widget.lang == 'en'
          ? 'No connection. Please try again.'
          : widget.lang == 'es'
              ? 'Sin conexión. Intenta de nuevo.'
              : 'Sem conexão. Tente novamente.';
    }
  }

  void _send([String? text]) async {
    final msg = (text ?? _inputCtrl.text).trim();
    if (msg.isEmpty || _loading) return;
    _inputCtrl.clear();

    setState(() {
      _messages.add({'role': 'user', 'content': msg});
      _loading = true;
    });
    _scrollDown();

    final reply = await _callAPI(msg);

    setState(() {
      _messages.add({'role': 'assistant', 'content': reply});
      _loading = false;
    });
    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PublicLeadFlowScaffold(
      lang: widget.lang,
      child: WatermarkBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── HEADER ──────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.blackCard,
                  border: Border(
                    bottom: BorderSide(
                        color: AppColors.gold.withOpacity(0.15)),
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.black,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppColors.gold.withOpacity(0.2)),
                        ),
                        child: const Icon(Icons.arrow_back,
                            size: 16, color: AppColors.gold),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Avatar Ana
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.gold.withOpacity(0.35)),
                      ),
                      child: const Center(
                        child: Text('A',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.gold)),
                      ),
                    ),
                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ana',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.white)),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2ECC71),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(_onlineLabel(),
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Botão consultor
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.gold.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.phone_outlined,
                                size: 12, color: AppColors.gold),
                            const SizedBox(width: 5),
                            Text(_consultantLabel(),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── MENSAGENS ───────────────────
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  itemCount: _messages.length + (_loading ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _messages.length && _loading) {
                      return const _TypingIndicator();
                    }
                    final msg = _messages[i];
                    return _Bubble(
                      text: msg['content']!,
                      isUser: msg['role'] == 'user',
                    );
                  },
                ),
              ),

              // ── SUGESTÕES ───────────────────
              if (_messages.length <= 1)
                SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 16),
                    children: _suggestions
                        .map((s) => _Chip(
                              text: s,
                              onTap: () => _send(s),
                            ))
                        .toList(),
                  ),
                ),

              // ── INPUT ───────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                decoration: BoxDecoration(
                  color: AppColors.blackCard,
                  border: Border(
                    top: BorderSide(
                        color: AppColors.gold.withOpacity(0.12)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.black,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color: AppColors.gold.withOpacity(0.2)),
                        ),
                        child: TextField(
                          controller: _inputCtrl,
                          style: const TextStyle(
                              color: AppColors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: _hintText(),
                            hintStyle: const TextStyle(
                                color: AppColors.grey, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 11),
                          ),
                          onSubmitted: (_) => _send(),
                          textInputAction: TextInputAction.send,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _send,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(Icons.send_rounded,
                            size: 18, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const _Bubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.gold.withOpacity(0.3)),
              ),
              child: const Center(
                child: Text('A',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.gold)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.gold.withOpacity(0.12)
                    : AppColors.blackCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? AppColors.gold.withOpacity(0.25)
                      : AppColors.gold.withOpacity(0.08),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: isUser
                      ? AppColors.gold
                      : AppColors.whitesoft,
                  height: 1.55,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('A',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.gold)),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.blackCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.gold.withOpacity(0.08)),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Row(
                children: List.generate(3, (i) {
                  final delay = i * 0.3;
                  final opacity =
                      ((_ctrl.value - delay) % 1.0).clamp(0.2, 1.0);
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2),
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _Chip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: AppColors.gold.withOpacity(0.25)),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, color: AppColors.whitesoft)),
      ),
    );
  }
}
