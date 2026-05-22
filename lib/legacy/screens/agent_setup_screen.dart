import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:hitlook/core/constants/firestore_paths.dart';
import 'package:hitlook/data/models/seller.dart';
import 'package:hitlook/legacy/admin/agent_profile_photo.dart';
import 'package:hitlook/legacy/screens/agent_profile.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';
import 'package:hitlook/legacy/widgets/flow_ux.dart';

class AgentSetupScreen extends StatefulWidget {
  const AgentSetupScreen({super.key});

  @override
  State<AgentSetupScreen> createState() => _AgentSetupScreenState();
}

class _AgentSetupScreenState extends State<AgentSetupScreen> {
  final _nomeCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _senhaAtualCtrl = TextEditingController();
  final _senhaNovaCtrl = TextEditingController();
  final _senhaConfirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Uint8List? _fotoBytes;
  String? _fotoUrl;
  String? _fotoContentType;
  final ImagePicker _imagePicker = ImagePicker();
  String _idioma = 'pt';
  String _nicho = 'seguro';
  bool _loading = false;
  bool _salvando = false;
  bool _alterandoSenha = false;
  bool _obscureAtual = true;
  bool _obscureNova = true;
  bool _obscureConfirm = true;
  String _publicLinkId = '';

  @override
  void initState() {
    super.initState();
    _loadPerfil();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _bioCtrl.dispose();
    _whatsappCtrl.dispose();
    _instagramCtrl.dispose();
    _linkedinCtrl.dispose();
    _senhaAtualCtrl.dispose();
    _senhaNovaCtrl.dispose();
    _senhaConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPerfil({bool silent = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('agents')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      final publicId = await AgentProvider.resolvePublicLinkId(uid);

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _nomeCtrl.text = data['nome'] as String? ?? '';
        _bioCtrl.text = data['bio'] as String? ?? '';
        _whatsappCtrl.text = data['whatsapp'] as String? ?? '';
        _instagramCtrl.text = data['instagramUrl'] as String? ?? '';
        _linkedinCtrl.text = data['linkedinUrl'] as String? ?? '';
        _idioma = data['idioma'] as String? ?? 'pt';
        _nicho = data['nicho'] as String? ?? 'seguro';
        final url = AgentPhotoPersistence.readUrlFromAgentMap(data);
        debugPrint('[HitLook:Profile] load agents/$uid fotoUrl=$url');

        Uint8List? storageBytes;
        if (url != null) {
          try {
            storageBytes = await FirebaseStorage.instance
                .ref()
                .child('agents/$uid/photo')
                .getData(AgentPhotoPersistence.maxPhotoBytes);
            debugPrint(
              '[HitLook:Profile] storage bytes=${storageBytes?.length ?? 0}',
            );
          } catch (e) {
            debugPrint('[HitLook:Profile] storage read: $e');
          }
        }

        if (mounted) {
          setState(() {
            _fotoUrl = url;
            _publicLinkId = publicId;
            if (storageBytes != null && storageBytes.isNotEmpty) {
              _fotoBytes = storageBytes;
            } else if (url == null) {
              _fotoBytes = null;
            }
          });
        }
      } else {
        debugPrint('[HitLook:Profile] agents/$uid doc missing');
        if (mounted) setState(() => _publicLinkId = publicId);
      }
    } catch (e, st) {
      debugPrint('[HitLook:Profile] load FAILED: $e\n$st');
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar perfil: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (!silent && mounted) setState(() => _loading = false);
  }

  Future<void> _selecionarFoto() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível ler a imagem. Tente outro arquivo.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _fotoBytes = bytes;
        _fotoContentType = picked.mimeType ?? _mimeFromName(picked.name);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar foto: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<String?> _uploadFoto(String uid) async {
    if (_fotoBytes == null) return _fotoUrl;
    return AgentPhotoPersistence.upload(
      uid: uid,
      bytes: _fotoBytes!,
      contentType: _fotoContentType ?? 'image/jpeg',
    );
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preencha nome e WhatsApp antes de salvar.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sessão expirada. Faça login novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    setState(() => _salvando = true);
    try {
      String? foto;
      if (_fotoBytes != null) {
        foto = await _uploadFoto(uid);
        if (foto == null || foto.trim().isEmpty) {
          throw Exception(
            'A foto foi enviada mas não gerou URL. Tente outra imagem.',
          );
        }
      } else {
        foto = _fotoUrl;
      }
      final nome = _nomeCtrl.text.trim();
      final bio = _bioCtrl.text.trim();
      final whatsapp = _whatsappCtrl.text.trim();
      final fotoFinal = foto?.trim() ?? '';

      final instagram = _instagramCtrl.text.trim();
      final linkedin = _linkedinCtrl.text.trim();

      final publicId = await AgentProvider.resolvePublicLinkId(uid);

      final agentPayload = <String, dynamic>{
        'nome': nome,
        'bio': bio,
        'whatsapp': whatsapp,
        'userId': uid,
        'idioma': _idioma,
        'nicho': _nicho,
        if (publicId != uid) 'slug': publicId,
        if (instagram.isNotEmpty) 'instagramUrl': instagram,
        if (linkedin.isNotEmpty) 'linkedinUrl': linkedin,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (fotoFinal.isNotEmpty) {
        agentPayload.addAll(AgentPhotoPersistence.photoFields(fotoFinal));
      }

      await FirebaseFirestore.instance
          .collection('agents')
          .doc(uid)
          .set(agentPayload, SetOptions(merge: true));

      if (_fotoBytes != null && fotoFinal.isNotEmpty) {
        final verifyDoc = await FirebaseFirestore.instance
            .collection('agents')
            .doc(uid)
            .get(const GetOptions(source: Source.server));
        final savedUrl = verifyDoc.exists && verifyDoc.data() != null
            ? AgentPhotoPersistence.readUrlFromAgentMap(verifyDoc.data()!)
            : null;
        if (savedUrl == null || savedUrl.isEmpty) {
          throw Exception(
            'A foto foi enviada mas não apareceu no perfil. Tente salvar de novo.',
          );
        }
        debugPrint('[HitLook:Profile] verify agents/$uid fotoUrl=$savedUrl');
      }

      debugPrint(
        '[HitLook:Profile] saved agents/$uid fotoUrl=$fotoFinal',
      );

      try {
        await _syncSellerAndPublicSlug(
          uid: uid,
          nome: nome,
          bio: bio,
          whatsapp: whatsapp,
          fotoUrl: fotoFinal,
          idioma: _idioma,
          nicho: _nicho,
          instagramUrl: instagram,
          linkedinUrl: linkedin,
        );
        debugPrint('[HitLook:Profile] synced seller + agents/{slug}');
      } catch (e, st) {
        debugPrint('[HitLook:Profile] sync warning: $e\n$st');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Perfil salvo, mas o link público pode demorar: $e',
              ),
              backgroundColor: const Color(0xFFF39C12),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          if (fotoFinal.isNotEmpty) _fotoUrl = fotoFinal;
          _publicLinkId = publicId;
        });
      }

      await _loadPerfil(silent: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              fotoFinal.isNotEmpty
                  ? 'Perfil salvo com foto!'
                  : 'Perfil salvo (sem foto).',
            ),
            backgroundColor: AppColors.gold,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[HitLook:Profile] save FAILED: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
    setState(() => _salvando = false);
  }

  /// Keeps SaaS seller + public slug doc in sync with legacy `agents/{uid}`.
  Future<void> _alterarSenha() async {
    final atual = _senhaAtualCtrl.text;
    final nova = _senhaNovaCtrl.text;
    final confirm = _senhaConfirmCtrl.text;

    if (atual.isEmpty || nova.isEmpty || confirm.isEmpty) {
      _snack('Preencha todos os campos de senha.', isError: true);
      return;
    }
    if (nova.length < 6) {
      _snack('A nova senha deve ter pelo menos 6 caracteres.', isError: true);
      return;
    }
    if (nova != confirm) {
      _snack('A confirmação não coincide com a nova senha.', isError: true);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      _snack('Sessão inválida. Faça login novamente.', isError: true);
      return;
    }

    setState(() => _alterandoSenha = true);
    try {
      final cred = EmailAuthProvider.credential(
        email: email,
        password: atual,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(nova);
      _senhaAtualCtrl.clear();
      _senhaNovaCtrl.clear();
      _senhaConfirmCtrl.clear();
      _snack('Senha alterada com sucesso!');
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'wrong-password' || 'invalid-credential' => 'Senha atual incorreta.',
        'weak-password' => 'Senha fraca. Use pelo menos 6 caracteres.',
        _ => e.message ?? 'Não foi possível alterar a senha.',
      };
      _snack(msg, isError: true);
    } catch (e) {
      _snack('Erro: $e', isError: true);
    } finally {
      if (mounted) setState(() => _alterandoSenha = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFE74C3C) : AppColors.gold,
      ),
    );
  }

  Future<void> _syncSellerAndPublicSlug({
    required String uid,
    required String nome,
    required String bio,
    required String whatsapp,
    required String fotoUrl,
    required String idioma,
    required String nicho,
    required String instagramUrl,
    required String linkedinUrl,
  }) async {
    final userSnap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!userSnap.exists || userSnap.data() == null) return;

    final companyId = userSnap.data()!['companyId'] as String?;
    final sellerId = userSnap.data()!['sellerId'] as String?;
    if (companyId == null || sellerId == null) return;

    final sellerRef = FirebaseFirestore.instance
        .doc(FirestorePaths.companySeller(companyId, sellerId));

    final sellerSnap = await sellerRef.get();
    final slug = sellerSnap.data()?['slug'] as String? ?? sellerId;

    await sellerRef.set({
      'displayName': nome,
      'slug': slug,
      'bio': bio,
      'phone': whatsapp,
      if (fotoUrl.isNotEmpty) 'photoUrl': fotoUrl,
      'userId': uid,
      'idioma': idioma,
      'nicho': nicho,
      if (instagramUrl.isNotEmpty) 'instagramUrl': instagramUrl,
      if (linkedinUrl.isNotEmpty) 'linkedinUrl': linkedinUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint(
      '[HitLook:Profile] sync seller/$sellerId slug=$slug fotoUrl=$fotoUrl',
    );

    final mirrorPayload = <String, dynamic>{
      'nome': nome,
      'bio': bio,
      'whatsapp': whatsapp,
      'userId': uid,
      'slug': slug,
      'idioma': idioma,
      'nicho': nicho,
      if (instagramUrl.isNotEmpty) 'instagramUrl': instagramUrl,
      if (linkedinUrl.isNotEmpty) 'linkedinUrl': linkedinUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (fotoUrl.isNotEmpty) {
      mirrorPayload.addAll(AgentPhotoPersistence.photoFields(fotoUrl));
    }
    await FirebaseFirestore.instance
        .collection('agents')
        .doc(slug)
        .set(mirrorPayload, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: WatermarkBackground(
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.gold))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        FlowBackButton(onPressed: () => context.go('/dashboard')),
                        const SizedBox(height: 24),

                        const M4LifeLogo(fontSize: 18, showTagline: false),

                        const SizedBox(height: 28),

                        Container(width: 40, height: 2, color: AppColors.gold),

                        const SizedBox(height: 16),

                        const Text(
                          'MEU PERFIL',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.white,
                            letterSpacing: 2,
                          ),
                        ),

                        const SizedBox(height: 6),

                        const Text(
                          'Configure como seus clientes vão te ver.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.greyLight,
                          ),
                        ),

                        const SizedBox(height: 32),

                        Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AgentProfilePhoto(
                                displayName: _nomeCtrl.text.isNotEmpty
                                    ? _nomeCtrl.text
                                    : 'Agente',
                                storageUid:
                                    FirebaseAuth.instance.currentUser?.uid,
                                photoUrl: _fotoUrl,
                                previewBytes: _fotoBytes,
                                size: 100,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Material(
                                  color: AppColors.gold,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    onTap: _selecionarFoto,
                                    customBorder: const CircleBorder(),
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.camera_alt_outlined,
                                        size: 18,
                                        color: AppColors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        Center(
                          child: Text(
                            _fotoBytes != null
                                ? 'Preview — salve para publicar a foto'
                                : 'Toque no ícone da câmera para enviar foto',
                            style: TextStyle(
                              fontSize: 12,
                              color: _fotoBytes != null
                                  ? AppColors.gold
                                  : AppColors.greyLight,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        _Campo(
                          ctrl: _nomeCtrl,
                          label: 'NOME COMPLETO',
                          hint: 'Como você se apresenta',
                          icon: Icons.person_outline,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Digite seu nome'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        _Campo(
                          ctrl: _bioCtrl,
                          label: 'APRESENTACAO',
                          hint: 'Ex: Especialista em proteção familiar',
                          icon: Icons.info_outline,
                          validator: (v) => null,
                        ),

                        const SizedBox(height: 16),

                        _Campo(
                          ctrl: _whatsappCtrl,
                          label: 'WHATSAPP',
                          hint: '+1 (786) 555-1234',
                          icon: Icons.chat_outlined,
                          tipo: TextInputType.phone,
                          helpText:
                              'Inclua o código do país. Ex: +1 para EUA, +55 para Brasil',
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Digite seu WhatsApp'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        _DropdownCampo(
                          label: 'IDIOMA PREFERIDO',
                          value: _idioma,
                          items: SellerProfileLabels.idiomas,
                          onChanged: (v) => setState(() => _idioma = v),
                        ),

                        const SizedBox(height: 16),

                        _DropdownCampo(
                          label: 'NICHO',
                          value: _nicho,
                          items: SellerProfileLabels.nichos,
                          onChanged: (v) => setState(() => _nicho = v),
                        ),

                        const SizedBox(height: 16),

                        _Campo(
                          ctrl: _instagramCtrl,
                          label: 'INSTAGRAM (opcional)',
                          hint: 'https://instagram.com/seu-perfil',
                          icon: Icons.camera_alt_outlined,
                        ),

                        const SizedBox(height: 16),

                        _Campo(
                          ctrl: _linkedinCtrl,
                          label: 'LINKEDIN (opcional)',
                          hint: 'https://linkedin.com/in/seu-perfil',
                          icon: Icons.work_outline,
                        ),

                        const SizedBox(height: 16),

                        Builder(
                          builder: (context) {
                            final publicId = _publicLinkId.isNotEmpty
                                ? _publicLinkId
                                : (FirebaseAuth.instance.currentUser?.uid ??
                                    'seu-link');
                            final link =
                                'https://hitlook-app.web.app/a/$publicId';
                            return GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: link));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Link copiado!'),
                                    backgroundColor: AppColors.gold,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.blackCard,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.gold.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.link,
                                        size: 16, color: AppColors.gold),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        link.replaceFirst('https://', ''),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.greyLight,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(Icons.copy_outlined,
                                        size: 16, color: AppColors.gold),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 28),

                        const Text(
                          'SEGURANÇA',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.gold,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 12),

                        _Campo(
                          ctrl: _senhaAtualCtrl,
                          label: 'SENHA ATUAL',
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                          obscure: _obscureAtual,
                          onToggleObscure: () =>
                              setState(() => _obscureAtual = !_obscureAtual),
                        ),

                        const SizedBox(height: 12),

                        _Campo(
                          ctrl: _senhaNovaCtrl,
                          label: 'NOVA SENHA',
                          hint: 'Mínimo 6 caracteres',
                          icon: Icons.lock_reset,
                          obscure: _obscureNova,
                          onToggleObscure: () =>
                              setState(() => _obscureNova = !_obscureNova),
                        ),

                        const SizedBox(height: 12),

                        _Campo(
                          ctrl: _senhaConfirmCtrl,
                          label: 'CONFIRMAR NOVA SENHA',
                          hint: 'Repita a nova senha',
                          icon: Icons.lock_reset,
                          obscure: _obscureConfirm,
                          onToggleObscure: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _alterandoSenha ? null : _alterarSenha,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.gold,
                              side: BorderSide(
                                color: AppColors.gold.withOpacity(0.5),
                              ),
                            ),
                            child: _alterandoSenha
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'ALTERAR SENHA',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _salvando ? null : _salvar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: AppColors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 0,
                            ),
                            child: _salvando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'SALVAR PERFIL',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                          ),
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

class _DropdownCampo extends StatelessWidget {
  const _DropdownCampo({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

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
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: AppColors.blackCard,
          style: const TextStyle(color: AppColors.whiteWarm, fontSize: 15),
          decoration: InputDecoration(
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
          ),
          items: items.entries
              .map(
                (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
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
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? helpText;

  const _Campo({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.tipo = TextInputType.text,
    this.validator,
    this.obscure = false,
    this.onToggleObscure,
    this.helpText,
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
          obscureText: obscure,
          style: const TextStyle(color: AppColors.whiteWarm, fontSize: 15),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.grey, fontSize: 14),
            prefixIcon: Icon(icon,
                size: 18, color: AppColors.gold.withOpacity(0.6)),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.greyLight,
                      size: 20,
                    ),
                  ),
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
        if (helpText != null) ...[
          const SizedBox(height: 6),
          Text(
            helpText!,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.grey.withOpacity(0.9),
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}
