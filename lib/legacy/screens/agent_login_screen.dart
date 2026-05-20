import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hitlook/legacy/admin/admin_session.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';

class AgentLoginScreen extends StatefulWidget {
  const AgentLoginScreen({super.key});

  @override
  State<AgentLoginScreen> createState() => _AgentLoginScreenState();
}

class _AgentLoginScreenState extends State<AgentLoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeIn;

  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _resetLoading = false;
  bool _senhaVisivel = false;
  bool _isCadastro = false;
  String? _erro;
  String? _sucesso;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _recuperarSenha() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty) {
      setState(() {
        _erro = 'Digite seu email para recuperar a senha.';
        _sucesso = null;
      });
      return;
    }

    if (!email.contains('@')) {
      setState(() {
        _erro = 'Email inválido.';
        _sucesso = null;
      });
      return;
    }

    setState(() {
      _resetLoading = true;
      _erro = null;
      _sucesso = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        setState(() {
          _sucesso = 'Enviamos um link de recuperação para seu e-mail.';
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _erro = _traduzirErroReset(e.code);
      });
    } catch (_) {
      setState(() {
        _erro = 'Não foi possível enviar o e-mail. Tente novamente.';
      });
    }

    if (mounted) setState(() => _resetLoading = false);
  }

  Future<void> _esqueceuSenha() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'Digite seu email primeiro.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email de recuperação enviado!'),
            backgroundColor: AppColors.gold,
          ),
        );
      }
    } catch (e) {
      setState(() => _erro = 'Erro ao enviar email. Verifique o endereço.');
    }
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _erro = null;
      _sucesso = null;
    });

    try {
      if (_isCadastro) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _senhaCtrl.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _senhaCtrl.text.trim(),
        );
      }

      if (mounted) {
        final route = await AdminSession.postLoginRoute();
        context.go(route);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _erro = _traduzirErro(e.code);
      });
    } catch (e) {
      setState(() {
        _erro = 'Erro inesperado. Tente novamente.';
      });
    }

    setState(() => _loading = false);
  }

  String _traduzirErro(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Email não encontrado. Crie uma conta.';
      case 'wrong-password':
        return 'Senha incorreta. Tente novamente.';
      case 'email-already-in-use':
        return 'Email já cadastrado. Faça login.';
      case 'weak-password':
        return 'Senha fraca. Use pelo menos 6 caracteres.';
      case 'invalid-email':
        return 'Email inválido.';
      case 'invalid-credential':
        return 'Email ou senha incorretos.';
      default:
        return 'Erro ao entrar. Tente novamente.';
    }
  }

  String _traduzirErroReset(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Email inválido.';
      case 'user-not-found':
        return 'Não encontramos uma conta com este e-mail.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
      case 'network-request-failed':
        return 'Sem conexão. Verifique sua internet e tente novamente.';
      default:
        return 'Não foi possível enviar o e-mail. Tente novamente.';
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
                    const SizedBox(height: 48),

                    const M4LifeLogo(fontSize: 22, showTagline: true),

                    const SizedBox(height: 40),

                    Container(width: 40, height: 2, color: AppColors.gold),

                    const SizedBox(height: 16),

                    Text(
                      _isCadastro ? 'CRIAR CONTA' : 'ÁREA DO AGENTE',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.white,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _isCadastro
                          ? 'Crie sua conta para acessar o painel.'
                          : 'Entre para gerenciar seus leads.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.greyLight,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Email
                    _Campo(
                      ctrl: _emailCtrl,
                      label: 'EMAIL',
                      hint: 'seu@email.com',
                      icon: Icons.email_outlined,
                      tipo: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Digite seu email';
                        }
                        if (!v.contains('@')) return 'Email inválido';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Senha
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SENHA',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.greyLight,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _senhaCtrl,
                          obscureText: !_senhaVisivel,
                          style: const TextStyle(
                            color: AppColors.whiteWarm,
                            fontSize: 15,
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Digite sua senha';
                            }
                            if (v.length < 6) {
                              return 'Mínimo 6 caracteres';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            hintStyle: const TextStyle(
                              color: AppColors.grey,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              size: 18,
                              color: AppColors.gold.withOpacity(0.6),
                            ),
                            suffixIcon: GestureDetector(
                              onTap: () => setState(
                                  () => _senhaVisivel = !_senhaVisivel),
                              child: Icon(
                                _senhaVisivel
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: AppColors.greyLight,
                              ),
                            ),
                            filled: true,
                            fillColor: AppColors.blackCard,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: AppColors.gold.withOpacity(0.15),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: AppColors.gold.withOpacity(0.15),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: AppColors.gold,
                                width: 1,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: Color(0xFFE74C3C),
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: Color(0xFFE74C3C),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                        if (!_isCadastro) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: _resetLoading || _loading
                                  ? null
                                  : _recuperarSenha,
                              child: _resetLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.gold,
                                      ),
                                    )
                                  : const Text(
                                      'Esqueceu a senha?',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Sucesso (recuperação de senha)
                    if (_sucesso != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2ECC71).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF2ECC71).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 16,
                              color: Color(0xFF2ECC71),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _sucesso!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF2ECC71),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Erro
                    if (_erro != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE74C3C).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFE74C3C).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 16,
                              color: Color(0xFFE74C3C),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _erro!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFE74C3C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Botão entrar
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading || _resetLoading ? null : _entrar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isCadastro ? 'CRIAR CONTA' : 'ENTRAR',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Toggle login/cadastro
                    Center(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isCadastro = !_isCadastro;
                          _erro = null;
                          _sucesso = null;
                        }),
                        child: Text(
                          _isCadastro
                              ? 'Já tem conta? Fazer login'
                              : 'Não tem conta? Criar agora',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.gold,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Esqueceu senha
                    if (!_isCadastro)
                      Center(
                        child: GestureDetector(
                          onTap: _esqueceuSenha,
                          child: Text(
                            'Esqueceu a senha?',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.greyLight,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 32),

                    // Divisor
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppColors.accentDim,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'ou',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppColors.accentDim,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Botão voltar para o app do cliente
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          context.go('/');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.greyLight,
                          side: BorderSide(
                            color: AppColors.accentDim,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Sou cliente — ver minha análise',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Center(
                      child: Text(
                        'Ferramenta educacional. Não constitui aconselhamento de seguros.',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.grey.withOpacity(0.5),
                        ),
                        textAlign: TextAlign.center,
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

class _Campo extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType tipo;
  final String? Function(String?)? validator;

  const _Campo({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.tipo = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.greyLight,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: tipo,
          style: const TextStyle(color: AppColors.whiteWarm, fontSize: 15),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.grey, fontSize: 14),
            prefixIcon: Icon(icon,
                size: 18, color: AppColors.gold.withOpacity(0.6)),
            filled: true,
            fillColor: AppColors.blackCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  BorderSide(color: AppColors.gold.withOpacity(0.15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  BorderSide(color: AppColors.gold.withOpacity(0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.gold, width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFE74C3C)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFE74C3C)),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
