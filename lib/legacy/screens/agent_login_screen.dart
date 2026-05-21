import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hitlook/core/constants/route_paths.dart';
import 'package:hitlook/legacy/admin/admin_session.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';

class AgentLoginScreen extends StatefulWidget {
  const AgentLoginScreen({super.key, this.passwordResetOobCode});

  /// From `/login?mode=resetPassword&oobCode=...` (email link).
  final String? passwordResetOobCode;

  @override
  State<AgentLoginScreen> createState() => _AgentLoginScreenState();
}

class _AgentLoginScreenState extends State<AgentLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _novaSenhaCtrl = TextEditingController();
  final _confirmarSenhaCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _resetLoading = false;
  bool _confirmResetLoading = false;
  bool _senhaVisivel = false;
  bool _novaSenhaVisivel = false;
  String? _erro;
  String? _sucesso;
  String? _oobCode;
  bool _definirNovaSenha = false;

  static const _resetContinueUrl = 'https://hitlook-app.web.app/login';

  @override
  void initState() {
    super.initState();
    _iniciarFluxoRedefinicaoSenha();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _novaSenhaCtrl.dispose();
    _confirmarSenhaCtrl.dispose();
    super.dispose();
  }

  void _iniciarFluxoRedefinicaoSenha() {
    final code = widget.passwordResetOobCode;
    if (code != null && code.isNotEmpty) {
      _oobCode = code;
      _definirNovaSenha = true;
      debugPrint('[HitLook:auth] password reset link opened (oobCode present)');
    }
  }

  Future<void> _irParaLoginLimpo({String? mensagemSucesso}) async {
    if (!mounted) return;
    setState(() {
      _definirNovaSenha = false;
      _oobCode = null;
      _confirmResetLoading = false;
      if (mensagemSucesso != null) _sucesso = mensagemSucesso;
    });
    context.go(RoutePaths.login);
  }

  Future<void> _confirmarNovaSenha() async {
    if (!_resetFormKey.currentState!.validate()) return;
    final code = _oobCode;
    if (code == null || code.isEmpty) {
      setState(() {
        _erro = 'Link inválido ou expirado. Solicite um novo e-mail.';
        _sucesso = null;
      });
      return;
    }

    setState(() {
      _confirmResetLoading = true;
      _erro = null;
      _sucesso = null;
    });

    final newPassword = _novaSenhaCtrl.text;

    try {
      debugPrint('[HitLook:auth] verifyPasswordResetCode…');
      final email = await FirebaseAuth.instance.verifyPasswordResetCode(code);
      debugPrint('[HitLook:auth] confirmPasswordReset for $email');

      await FirebaseAuth.instance.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );

      _novaSenhaCtrl.clear();
      _confirmarSenhaCtrl.clear();

      // Entrar automaticamente com a senha recém-definida (evita erro de digitação).
      debugPrint('[HitLook:auth] signIn after reset for $email');
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: newPassword,
      );

      if (!mounted) return;
      final route = await AdminSession.postLoginRoute();
      debugPrint('[HitLook:auth] reset+login OK → $route');
      context.go(route);
    } on FirebaseAuthException catch (e, st) {
      debugPrint(
        '[HitLook:auth] reset/sign-in failed: ${e.code} ${e.message}\n$st',
      );
      if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        await _irParaLoginLimpo(
          mensagemSucesso:
              'Senha alterada. Faça login com o e-mail do link e a nova senha.',
        );
        if (mounted) {
          setState(() {
            _erro = null;
          });
        }
      } else {
        setState(() {
          _erro = _traduzirErroConfirmReset(e.code);
        });
      }
    } catch (e, st) {
      debugPrint('[HitLook:auth] reset unexpected: $e\n$st');
      setState(() {
        _erro = 'Não foi possível alterar a senha. Solicite um novo link.';
      });
    }

    if (mounted) setState(() => _confirmResetLoading = false);
  }

  Future<void> _recuperarSenha() async {
    final email = _emailCtrl.text.trim().toLowerCase();

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
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: ActionCodeSettings(
          url: _resetContinueUrl,
          handleCodeInApp: false,
        ),
      );
      if (mounted) {
        setState(() {
          _sucesso =
              'Enviamos um link para $email. Abra o e-mail (ou spam), '
              'defina a nova senha no link e só então volte aqui para entrar.';
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

  Future<void> _entrar() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _erro = null;
      _sucesso = null;
    });

    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _senhaCtrl.text;

    try {
      debugPrint('[HitLook:auth] signIn $email');

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = FirebaseAuth.instance.currentUser?.uid;
      debugPrint('[HitLook:auth] Firebase Auth OK uid=$uid');

      if (!mounted) return;

      final route = await AdminSession.postLoginRoute();
      debugPrint('[HitLook:auth] navigating → $route');

      setState(() => _loading = false);
      if (!mounted) return;
      context.go(route);
      return;
    } on FirebaseAuthException catch (e, st) {
      debugPrint('[HitLook:auth] FirebaseAuthException: ${e.code} ${e.message}\n$st');
      setState(() {
        _erro = _traduzirErro(e.code);
      });
    } on FirebaseException catch (e, st) {
      // Auth succeeded; Firestore profile optional for legacy sellers.
      debugPrint('[HitLook:auth] Firestore after login: ${e.code} ${e.message}\n$st');
      setState(() => _loading = false);
      if (mounted) context.go(RoutePaths.dashboard);
      return;
    } catch (e, st) {
      debugPrint('[HitLook:auth] login unexpected: $e\n$st');
      setState(() {
        _erro = kDebugMode
            ? 'Erro: $e'
            : 'Erro inesperado. Tente novamente.';
      });
    }

    if (mounted) setState(() => _loading = false);
  }

  String _traduzirErro(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Email não encontrado. Solicite acesso ao administrador.';
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

  /// PT copy matches the rest of the login screen (Safari iOS often reports en-US).
  static const _restrictedAccessMessage =
      'Acesso restrito. Credenciais fornecidas pelo administrador.';

  ButtonStyle get _loginButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.black,
        disabledBackgroundColor: AppColors.gold,
        disabledForegroundColor: AppColors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 0,
        minimumSize: const Size(double.infinity, 56),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );

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

  String _traduzirErroConfirmReset(String code) {
    switch (code) {
      case 'expired-action-code':
        return 'Este link expirou. Clique em "Esqueceu a senha?" e solicite outro.';
      case 'invalid-action-code':
        return 'Link inválido. Solicite um novo e-mail de recuperação.';
      case 'weak-password':
        return 'Senha fraca. Use pelo menos 6 caracteres.';
      case 'user-disabled':
        return 'Esta conta está desativada. Fale com o suporte.';
      default:
        return 'Não foi possível definir a nova senha. Tente solicitar outro link.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_definirNovaSenha) {
      return _buildDefinirNovaSenha(context);
    }
    return Scaffold(
      backgroundColor: AppColors.black,
      body: WatermarkBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => context.go('/'),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.blackCard,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.gold.withOpacity(0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            size: 18,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const M4LifeLogo(fontSize: 22, showTagline: true),

                    const SizedBox(height: 40),

                    Container(width: 40, height: 2, color: AppColors.gold),

                    const SizedBox(height: 16),

                    const Text(
                      'ÁREA DO AGENTE',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.white,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Entre para gerenciar seus leads.',
                      style: TextStyle(
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
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
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
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _entrar(),
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
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _senhaVisivel = !_senhaVisivel,
                              ),
                              icon: Icon(
                                _senhaVisivel
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
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
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _resetLoading ? null : _recuperarSenha,
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
                        onPressed: _entrar,
                        style: _loginButtonStyle,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'ENTRAR',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      _restrictedAccessMessage,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.grey.withValues(alpha: 0.85),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
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
    );
  }

  Widget _buildDefinirNovaSenha(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: WatermarkBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _resetFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const M4LifeLogo(fontSize: 22, showTagline: false),
                  const SizedBox(height: 32),
                  Container(width: 40, height: 2, color: AppColors.gold),
                  const SizedBox(height: 16),
                  const Text(
                    'NOVA SENHA',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Defina sua nova senha abaixo. Depois volte ao login.',
                    style: TextStyle(fontSize: 14, color: AppColors.greyLight),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'NOVA SENHA',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.greyLight,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _novaSenhaCtrl,
                    obscureText: !_novaSenhaVisivel,
                    style: const TextStyle(color: AppColors.whiteWarm),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Digite a nova senha';
                      if (v.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      filled: true,
                      fillColor: AppColors.blackCard,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _novaSenhaVisivel
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.greyLight,
                          size: 18,
                        ),
                        onPressed: () => setState(
                          () => _novaSenhaVisivel = !_novaSenhaVisivel,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: AppColors.gold.withOpacity(0.15),
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                        borderSide: BorderSide(color: AppColors.gold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'CONFIRMAR SENHA',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.greyLight,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmarSenhaCtrl,
                    obscureText: !_novaSenhaVisivel,
                    style: const TextStyle(color: AppColors.whiteWarm),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Confirme a nova senha';
                      }
                      if (v != _novaSenhaCtrl.text) {
                        return 'As senhas não coincidem';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      filled: true,
                      fillColor: AppColors.blackCard,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: AppColors.gold.withOpacity(0.15),
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                        borderSide: BorderSide(color: AppColors.gold),
                      ),
                    ),
                  ),
                  if (_erro != null) ...[
                    const SizedBox(height: 12),
                    Text(_erro!, style: const TextStyle(color: Color(0xFFE74C3C))),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed:
                          _confirmResetLoading ? null : _confirmarNovaSenha,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.black,
                      ),
                      child: _confirmResetLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.black,
                              ),
                            )
                          : const Text(
                              'SALVAR NOVA SENHA',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text(
                        'Voltar ao login',
                        style: TextStyle(color: AppColors.gold),
                      ),
                    ),
                  ),
                ],
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
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;

  const _Campo({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.tipo = TextInputType.text,
    this.validator,
    this.autofillHints,
    this.textInputAction,
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
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          autocorrect: false,
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
