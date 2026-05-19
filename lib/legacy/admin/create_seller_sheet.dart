import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hitlook/core/utils/result.dart';
import 'package:hitlook/data/models/seller.dart';
import 'package:hitlook/data/repositories/firebase/firebase_seller_repository.dart';
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
  final _sellerRepo = FirebaseSellerRepository();

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

  Future<void> _save() async {
    _slugFromName();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final seller = Seller(
      id: '',
      companyId: widget.companyId,
      displayName: _nameCtrl.text.trim(),
      slug: _slugCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      isActive: true,
    );

    final result = await _sellerRepo.upsert(seller);
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
              'NOVO VENDEDOR',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cada vendedor recebe um link público único (/a/slug).',
              style: TextStyle(fontSize: 13, color: AppColors.greyLight),
            ),
            const SizedBox(height: 24),
            _field(
              controller: _nameCtrl,
              label: 'Nome',
              icon: Icons.person_outline,
              onChanged: (_) => _slugFromName(),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _slugCtrl,
              label: 'Slug do link (ex: maria-silva)',
              icon: Icons.link,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe o slug';
                if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(v.trim())) {
                  return 'Use apenas letras minúsculas, números e hífens';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _field(
              controller: _emailCtrl,
              label: 'E-mail (opcional)',
              icon: Icons.email_outlined,
              type: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _phoneCtrl,
              label: 'WhatsApp (opcional)',
              icon: Icons.phone_outlined,
              type: TextInputType.phone,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFE74C3C), fontSize: 13)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'CRIAR VENDEDOR',
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
              ),
            ),
          ],
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
