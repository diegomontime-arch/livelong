import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hitlook/legacy/admin/admin_seller_avatar.dart';

/// Avatar that loads agent photos via Storage SDK (avoids web CORS on [Image.network]).
class AgentProfilePhoto extends StatefulWidget {
  const AgentProfilePhoto({
    super.key,
    required this.displayName,
    this.storageUid,
    this.photoUrl,
    this.previewBytes,
    this.size = 56,
  });

  final String displayName;
  final String? storageUid;
  final String? photoUrl;
  final Uint8List? previewBytes;
  final double size;

  @override
  State<AgentProfilePhoto> createState() => _AgentProfilePhotoState();
}

class _AgentProfilePhotoState extends State<AgentProfilePhoto> {
  Uint8List? _storageBytes;
  bool _loadingStorage = false;

  @override
  void initState() {
    super.initState();
    _loadFromStorage();
  }

  @override
  void didUpdateWidget(AgentProfilePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storageUid != widget.storageUid ||
        oldWidget.photoUrl != widget.photoUrl ||
        oldWidget.previewBytes != widget.previewBytes) {
      _loadFromStorage();
    }
  }

  Future<void> _loadFromStorage() async {
    if (widget.previewBytes != null && widget.previewBytes!.isNotEmpty) {
      return;
    }
    final uid = widget.storageUid?.trim() ?? '';
    if (uid.isEmpty) return;

    setState(() => _loadingStorage = true);
    try {
      final ref = FirebaseStorage.instance.ref().child('agents/$uid/photo');
      final data = await ref.getData(4 * 1024 * 1024);
      if (!mounted) return;
      setState(() {
        _storageBytes = data;
        _loadingStorage = false;
      });
      debugPrint(
        '[HitLook:Photo] storage agents/$uid/photo bytes=${data?.length ?? 0}',
      );
    } catch (e, st) {
      debugPrint('[HitLook:Photo] storage load failed: $e\n$st');
      if (mounted) setState(() => _loadingStorage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.previewBytes;
    if (preview != null && preview.isNotEmpty) {
      return _circle(Image.memory(preview, fit: BoxFit.cover));
    }

    final cached = _storageBytes;
    if (cached != null && cached.isNotEmpty) {
      return _circle(Image.memory(cached, fit: BoxFit.cover));
    }

    if (_loadingStorage) {
      return _circle(
        const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return AdminSellerAvatar(
      displayName: widget.displayName,
      photoUrl: widget.photoUrl,
      size: widget.size,
    );
  }

  Widget _circle(Widget child) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.45),
          width: 1.5,
        ),
        color: const Color(0xFF0A0A0A),
      ),
      child: ClipOval(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: child,
        ),
      ),
    );
  }
}

/// Upload + Firestore field names used across legacy + SaaS seller docs.
abstract final class AgentPhotoPersistence {
  static const maxPhotoBytes = 4 * 1024 * 1024;

  static Map<String, String> photoFields(String url) => {
        'fotoUrl': url,
        'photoUrl': url,
      };

  static Future<String> upload({
    required String uid,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (bytes.isEmpty) {
      throw Exception('Arquivo de imagem vazio.');
    }
    if (bytes.length > maxPhotoBytes) {
      throw Exception('Imagem muito grande (máx. 4 MB).');
    }

    final ref = FirebaseStorage.instance.ref().child('agents/$uid/photo');
    debugPrint('[HitLook:Photo] upload agents/$uid/photo (${bytes.length} bytes)');

    await ref.delete().catchError((_) {});

    final task = await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        cacheControl: 'public,max-age=31536000',
      ),
    );

    if (task.state != TaskState.success) {
      throw Exception('Upload incompleto (${task.state}).');
    }

    final url = await ref.getDownloadURL();
    if (url.trim().isEmpty) {
      throw Exception('Upload OK mas URL vazia.');
    }

    // Confirma que o arquivo está legível (mesmo caminho usado na UI).
    final verify = await ref.getData(maxPhotoBytes);
    if (verify == null || verify.isEmpty) {
      throw Exception('Foto enviada mas não foi possível ler do Storage.');
    }

    debugPrint('[HitLook:Photo] upload OK url=$url verifyBytes=${verify.length}');
    return url;
  }

  static String? readUrlFromAgentMap(Map<String, dynamic> data) {
    final url = data['fotoUrl'] as String? ?? data['photoUrl'] as String?;
    final trimmed = url?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
