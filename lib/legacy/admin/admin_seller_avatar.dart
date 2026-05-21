import 'package:flutter/material.dart';

import 'package:hitlook/legacy/screens/agent_profile.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';

class AdminSellerAvatar extends StatelessWidget {
  const AdminSellerAvatar({
    super.key,
    required this.displayName,
    this.photoUrl,
    this.size = 56,
  });

  final String displayName;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim() ?? '';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45), width: 1.5),
        color: AppColors.black,
      ),
      child: url.isNotEmpty
          ? ClipOval(
              child: Image.network(
                url,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (_, __, ___) => _initials(),
              ),
            )
          : _initials(),
    );
  }

  Widget _initials() {
    final initials = agentInitials(displayName);
    return Center(
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w900,
          color: AppColors.gold,
        ),
      ),
    );
  }
}
