import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'language_screen.dart';
import 'agent_profile.dart';

class AgentSetupScreen extends StatefulWidget {
  const AgentSetupScreen({super.key});

  @override
  State<AgentSetupScreen> createState() => _AgentSetupScreenState();
}

class _AgentSetupScreenState extends State<AgentSetupScreen> {
  final _nomeCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Uint8List? _fotoBytes;
  String? _fotoUrl;
  bool _loading = false;
  bool _salvando = false;

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
    super.dispose();
  }

  Future<void> _loadPerfil() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('agents')
          .doc(uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _nomeCtrl.text = data['nome'] ?? '';
        _bioCtrl.text = data['bio'] ?? '';
        _whatsappCtrl.text = data['whatsapp'] ?? '';
        setState(() => _fotoUrl = data['fotoUrl']);
      }
    } catch (e) {}
    setState(() => _loading = false);
  }

  Future<void> _selecionarFoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 80,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _fotoBytes = bytes);
    }
  }

  Future<String?> _uploadFoto(String uid) async {
    if (_fotoBytes == null) return _fotoUrl;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('agents/$uid/photo');
      final task = await ref.putData(
        _fotoBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await task.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _salvando = true);
    try {
      final fotoUrl = await _uploadFoto(uid);
      await FirebaseFirestore.instance
          .collection('agents')
          .doc(uid)
          .set({
        'nome': _nomeCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'whatsapp': _whatsappCtrl.text.trim(),
        'fotoUrl': fotoUrl ?? '',
        'idioma': 'pt',
        'nicho': 'seguro',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil salvo com sucesso!'),
            backgroundColor: AppColors.gold,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _salvando = false);
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
                        const SizedBox(height: 40),

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

                        // Foto
                        Center(
                          child: GestureDetector(
                            onTap: _selecionarFoto,
                            child: Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.blackCard,
                                    border: Border.all(
                                      color: AppColors.gold,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: _fotoBytes != null
                                        ? Image.memory(_fotoBytes!,
                                            fit: BoxFit.cover)
                                        : _fotoUrl != null &&
                                                _fotoUrl!.isNotEmpty
                                            ? Image.network(_fotoUrl!,
                                                fit: BoxFit.cover)
                                            : const Center(
                                                child: Icon(
                                                  Icons.person_outline,
                                                  size: 40,
                                                  color: AppColors.gold,
                                                ),
                                              ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: AppColors.gold,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.black,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_outlined,
                                      size: 14,
                                      color: AppColors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Center(
                          child: Text(
                            'Toque para adicionar sua foto',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.greyLight,
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
                          hint: '13051234567 (só números)',
                          icon: Icons.chat_outlined,
                          tipo: TextInputType.phone,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Digite seu WhatsApp'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        Container(
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
                                  'hitlook-app.web.app/${FirebaseAuth.instance.currentUser?.uid ?? 'seu-link'}',
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

                        const SizedBox(height: 32),

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
