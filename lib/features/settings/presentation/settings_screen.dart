import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:hitlook/core/constants/route_paths.dart';
import 'package:hitlook/core/theme/app_colors.dart';
import 'package:hitlook/features/legal/presentation/legal_screen.dart';

/// Account & legal settings for the signed-in agent.
///
/// Layout (top → bottom):
///   1. **Profile**: shortcut to `/perfil` (full edit screen).
///   2. **Legal & support**: Privacy, Terms, About.
///   3. **Account**: Sign out, Delete account.
///
/// Reachable via `/settings` from the dashboard.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = info.version;
          _buildNumber = info.buildNumber;
        });
      }
    } catch (_) {
      // package_info_plus can fail in tests / unsupported platforms — ignore.
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.blackCard,
        title: const Text('Sair', style: TextStyle(color: AppColors.white)),
        content: const Text(
          'Você precisará entrar de novo para acessar seu painel.',
          style: TextStyle(color: AppColors.whiteWarm),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sair', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go(RoutePaths.root);
  }

  Future<void> _deleteAccount() async {
    final scaffold = ScaffoldMessenger.of(context);

    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.blackCard,
        title: const Text(
          'Excluir conta',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Esta ação não pode ser desfeita.\n\n'
          '• Seu perfil será removido em até 24h.\n'
          '• Os leads que você gerou ficarão visíveis para o administrador '
          'da sua empresa como histórico anonimizado.\n'
          '• Você não conseguirá mais entrar com este e-mail.',
          style: TextStyle(color: AppColors.whiteWarm, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Continuar',
              style: TextStyle(color: Color(0xFFE74C3C), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (firstConfirm != true) return;

    final password = await _askPasswordForReauth();
    if (password == null || password.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      scaffold.showSnackBar(const SnackBar(content: Text('Sessão inválida. Faça login de novo.')));
      return;
    }

    try {
      // Re-auth — Firebase requires recent login for sensitive ops.
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);

      // Server-side delete (anonymizes seller, deletes auth + storage + audit log).
      final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('deleteAgentAccount')
          .call();

      if (!mounted) return;
      scaffold.showSnackBar(SnackBar(
        content: Text(
          result.data is Map && result.data['success'] == true
              ? 'Sua conta foi excluída.'
              : 'Conta excluída.',
        ),
      ));
      // Auth user is gone — just go to root.
      await FirebaseAuth.instance.signOut().catchError((_) {});
      if (mounted) context.go(RoutePaths.root);
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'wrong-password' || 'invalid-credential' =>
          'Senha incorreta. Tente novamente.',
        'too-many-requests' =>
          'Muitas tentativas. Aguarde alguns minutos.',
        _ => 'Erro ao confirmar identidade: ${e.message ?? e.code}',
      };
      scaffold.showSnackBar(SnackBar(content: Text(msg)));
    } on FirebaseFunctionsException catch (e) {
      scaffold.showSnackBar(SnackBar(
        content: Text('Falha no servidor: ${e.message ?? e.code}'),
      ));
    } catch (e) {
      scaffold.showSnackBar(SnackBar(content: Text('Erro inesperado: $e')));
    }
  }

  Future<String?> _askPasswordForReauth() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.blackCard,
        title: const Text(
          'Confirme sua senha',
          style: TextStyle(color: AppColors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Por segurança, digite sua senha atual para continuar.',
              style: TextStyle(color: AppColors.whiteWarm),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              style: const TextStyle(color: AppColors.white),
              decoration: const InputDecoration(
                hintText: 'Senha',
                hintStyle: TextStyle(color: AppColors.grey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.goldDim),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.gold),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Confirmar', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: const Text(
          'Configurações',
          style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gold),
      ),
      body: ListView(
        children: [
          // ── Profile section ─────────────────────────────────────────
          const _SectionHeader('Perfil'),
          _Tile(
            icon: Icons.person_outline,
            label: 'Editar perfil',
            trailing: const Icon(Icons.chevron_right, color: AppColors.grey),
            onTap: () => context.push(RoutePaths.sellerProfile),
          ),
          const Divider(color: AppColors.blackCard, height: 1),

          // ── Legal section ───────────────────────────────────────────
          const _SectionHeader('Privacidade & Termos'),
          _Tile(
            icon: Icons.privacy_tip_outlined,
            label: 'Política de Privacidade',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const LegalScreen(document: LegalDocument.privacy, lang: 'pt'),
              ),
            ),
          ),
          _Tile(
            icon: Icons.description_outlined,
            label: 'Termos de Uso',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const LegalScreen(document: LegalDocument.terms, lang: 'pt'),
              ),
            ),
          ),
          const Divider(color: AppColors.blackCard, height: 1),

          // ── About section ───────────────────────────────────────────
          const _SectionHeader('Sobre'),
          _Tile(
            icon: Icons.info_outline,
            label: 'Versão do app',
            trailing: Text(
              _appVersion.isEmpty
                  ? '—'
                  : 'v$_appVersion (build $_buildNumber)',
              style: const TextStyle(color: AppColors.greyLight, fontSize: 12),
            ),
            onTap: null,
          ),
          _Tile(
            icon: Icons.email_outlined,
            label: 'Contato de suporte',
            trailing: const Text(
              'support@hitlook.us',
              style: TextStyle(color: AppColors.greyLight, fontSize: 12),
            ),
            onTap: null,
          ),
          const Divider(color: AppColors.blackCard, height: 1),

          // ── Account section ─────────────────────────────────────────
          const _SectionHeader('Conta'),
          _Tile(
            icon: Icons.logout,
            label: 'Sair',
            color: AppColors.gold,
            onTap: _signOut,
          ),
          _Tile(
            icon: Icons.delete_forever_outlined,
            label: 'Excluir minha conta',
            color: const Color(0xFFE74C3C),
            onTap: _deleteAccount,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 3,
          fontWeight: FontWeight.w700,
          color: AppColors.gold,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    this.trailing,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppColors.whiteWarm;
    return ListTile(
      leading: Icon(icon, color: fg, size: 22),
      title: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w500)),
      trailing: trailing,
      onTap: onTap,
      tileColor: AppColors.black,
      hoverColor: AppColors.blackCard,
    );
  }
}
