import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:hitlook/core/config/app_config.dart';
import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/models/seller.dart';
import 'package:hitlook/legacy/admin/create_seller_service.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';

Future<Seller?> showCreateSellerSheet({
  required BuildContext context,
  required String companyId,
}) {
  return showModalBottomSheet<Seller>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.blackCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _CreateSellerSheet(companyId: companyId),
  );
}

class _CreateSellerSheet extends StatefulWidget {
  const _CreateSellerSheet({required this.companyId});

  final String companyId;

  @override
  State<_CreateSellerSheet> createState() => _CreateSellerSheetState();
}

class _CreateSellerSheetState extends State<_CreateSellerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _createService = CreateSellerService();
  final _imagePicker = ImagePicker();

  Uint8List? _photoBytes;
  String? _photoContentType;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _slugCtrl.dispose();
    super.dispose();
  }

  void _slugFromName() {
    if (_slugCtrl.text.isNotEmpty) return;
    final slug = _nameCtrl.text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isNotEmpty) _slugCtrl.text = slug;
  }

  Future<void> _pickPhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _photoContentType = picked.mimeType ?? 'image/jpeg';
    });
  }

  Future<void> _save() async {
    _slugFromName();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _createService.create(
      companyId: widget.companyId,
      displayName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      slug: _slugCtrl.text.trim(),
      photoBytes: _photoBytes,
      photoContentType: _photoContentType,
    );

    if (!mounted) return;

    switch (result) {
      case Success(value: final saved):
        Navigator.pop(context, saved);
      case Error(failure: final f):
        setState(() {
          _error = f.message;
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'ADICIONAR AGENTE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Senha temporária: ${AppConfig.defaultSellerPassword}',
                style: const TextStyle(fontSize: 12, color: AppColors.greyLight),
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.black,
                    backgroundImage:
                        _photoBytes != null ? MemoryImage(_photoBytes!) : null,
                    child: _photoBytes == null
                        ? const Icon(Icons.add_a_photo, color: AppColors.gold)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _field(
                controller: _nameCtrl,
                label: 'Nome completo',
                icon: Icons.person_outline,
                onChanged: (_) => _slugFromName(),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _emailCtrl,
                label: 'E-mail',
                icon: Icons.email_outlined,
                type: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                  if (!v.contains('@')) return 'E-mail inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _field(
                controller: _phoneCtrl,
                label: 'WhatsApp',
                icon: Icons.phone_outlined,
                type: TextInputType.phone,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Informe o WhatsApp' : null,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _slugCtrl,
                label: 'Slug do link (ex: renan)',
                icon: Icons.link,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o slug';
                  if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(v.trim())) {
                    return 'Use apenas letras minúsculas, números e hífens';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: Color(0xFFE74C3C), fontSize: 13)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'CRIAR AGENTE',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(color: AppColors.whiteWarm),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.greyLight, fontSize: 12),
        prefixIcon: Icon(icon, size: 18, color: AppColors.gold),
        filled: true,
        fillColor: AppColors.black,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
      ),
    );
  }
}
