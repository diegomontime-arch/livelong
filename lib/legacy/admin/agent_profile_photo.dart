import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hitlook/legacy/admin/admin_seller_avatar.dart';

/// Avatar that loads agent photos via HTTP URL or Storage SDK (web-safe).
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
  Uint8List? _imageBytes;
  bool _loading = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  @override
  void didUpdateWidget(AgentProfilePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storageUid != widget.storageUid ||
        oldWidget.photoUrl != widget.photoUrl ||
        oldWidget.previewBytes != widget.previewBytes) {
      _loadPhoto();
    }
  }

  Future<void> _loadPhoto() async {
    if (widget.previewBytes != null && widget.previewBytes!.isNotEmpty) {
      return;
    }

    final generation = ++_loadGeneration;
    final uid = widget.storageUid?.trim() ?? '';
    final url = widget.photoUrl?.trim() ?? '';

    debugPrint(
      '[Photo] AgentProfilePhoto load uid=$uid url=${url.isNotEmpty ? url.substring(0, url.length.clamp(0, 80)) : "(empty)"}',
    );

    if (uid.isEmpty && url.isEmpty) {
      debugPrint('[Photo] AgentProfilePhoto skip — sem uid e sem url');
      return;
    }

    if (mounted) setState(() => _loading = true);

    Uint8List? bytes;

    // Web: URL primeiro (CORS no bucket); depois Storage getData.
    if (kIsWeb && url.isNotEmpty) {
      bytes = await _fetchUrlBytes(url);
    }

    if ((bytes == null || bytes.isEmpty) && uid.isNotEmpty) {
      try {
        final ref = FirebaseStorage.instance.ref().child('agents/$uid/photo');
        bytes = await ref.getData(AgentPhotoPersistence.maxPhotoBytes);
        debugPrint(
          '[Photo] storage agents/$uid/photo bytes=${bytes?.length ?? 0}',
        );
      } catch (e, st) {
        debugPrint('[Photo] storage failed: $e\n$st');
      }
    }

    if ((bytes == null || bytes.isEmpty) && !kIsWeb && url.isNotEmpty) {
      bytes = await _fetchUrlBytes(url);
    }

    if (!mounted || generation != _loadGeneration) return;

    setState(() {
      _imageBytes = bytes;
      _loading = false;
    });

    debugPrint(
      '[Photo] AgentProfilePhoto done bytes=${bytes?.length ?? 0} loading=$_loading',
    );
  }

  Future<Uint8List?> _fetchUrlBytes(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        debugPrint('[Photo] url fetch OK bytes=${response.bodyBytes.length}');
        return response.bodyBytes;
      }
      debugPrint('[Photo] url fetch status=${response.statusCode}');
    } catch (e, st) {
      debugPrint('[Photo] url fetch failed: $e\n$st');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.previewBytes;
    if (preview != null && preview.isNotEmpty) {
      return _circle(Image.memory(preview, fit: BoxFit.cover));
    }

    final cached = _imageBytes;
    if (cached != null && cached.isNotEmpty) {
      return _circle(Image.memory(cached, fit: BoxFit.cover));
    }

    if (_loading) {
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

    final url = widget.photoUrl?.trim() ?? '';
    if (kIsWeb && url.isNotEmpty) {
      debugPrint('[Photo] AgentProfilePhoto fallback Image.network');
      return _circle(
        Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, error, __) {
            debugPrint('[Photo] Image.network error: $error');
            return AdminSellerAvatar(
              displayName: widget.displayName,
              photoUrl: null,
              size: widget.size,
            );
          },
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

  /// Ignora `fotoUrl: ''` e usa `photoUrl` quando o legado gravou string vazia.
  static String? readUrlFromAgentMap(Map<String, dynamic> data) {
    for (final key in ['photoUrl', 'fotoUrl']) {
      final raw = data[key];
      if (raw is! String) continue;
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
}
