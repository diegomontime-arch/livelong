import 'package:flutter/material.dart';

/// Design tokens shared across features.
///
/// Source of truth for the M4LIFE dark+gold theme. Legacy screens still
/// define their own copy of [AppColors] inside `lib/legacy/screens/language_screen.dart`
/// for historical reasons — keep these two in sync. New feature code
/// (under `lib/features/...`) should always import this one.
abstract final class AppColors {
  static const black = Color(0xFF000000);
  static const blackCard = Color(0xFF0D0D0D);
  static const blackLight = Color(0xFF1A1A1A);
  static const white = Color(0xFFFFFFFF);
  static const whiteWarm = Color(0xFFF5F0EB);
  static const whiteSoft = Color(0xFFE8E8E8);
  static const whiteDim = Color(0xFFAAAAAA);
  static const grey = Color(0xFF555555);
  static const greyLight = Color(0xFF888888);
  static const gold = Color(0xFFD4AF37);
  static const goldDim = Color(0xFF8B7420);
  static const goldGlow = Color(0x22D4AF37);
  static const accent = Color(0xFFFFFFFF);
  static const accentDim = Color(0xFF444444);
}
