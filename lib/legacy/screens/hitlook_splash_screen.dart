import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hitlook/legacy/screens/language_screen.dart';

/// Branded splash (1.5s). Visual only — must not change routes when embedded.
class HitLookSplashScreen extends StatefulWidget {
  const HitLookSplashScreen({
    super.key,
    this.destination,
    this.onFinished,
  }) : assert(
          destination != null || onFinished != null,
          'Provide destination (router) or onFinished (embedded)',
        );

  /// Router mode: navigate here after splash (path only, e.g. `/a/diego-teste`).
  final String? destination;

  /// Embedded mode: callback instead of [GoRouter] navigation.
  final VoidCallback? onFinished;

  @override
  State<HitLookSplashScreen> createState() => _HitLookSplashScreenState();
}

class _HitLookSplashScreenState extends State<HitLookSplashScreen>
    with TickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1500);

  late final AnimationController _fadeCtrl;
  late final AnimationController _progressCtrl;
  late final Animation<double> _logoOpacity;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _progressCtrl = AnimationController(vsync: this, duration: _duration);
    _logoOpacity = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _progressCtrl.forward();

    _timer = Timer(_duration, _finish);
  }

  void _finish() {
    if (!mounted) return;

    final onFinished = widget.onFinished;
    if (onFinished != null) {
      onFinished();
      return;
    }

    final raw = widget.destination?.trim() ?? '/';
    final dest = Uri.parse(raw);
    // Navega só pelo path — sem query params que corrompem o slug.
    final path = dest.path.isEmpty ? '/' : dest.path;
    debugPrint('[HitLook:Splash] go → $path (from raw=$raw)');
    context.go(path);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          Center(
            child: FadeTransition(
              opacity: _logoOpacity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HitLookLogo(fontSize: 42, letterSpacing: 8),
                  const SizedBox(height: 12),
                  Text(
                    'AI · PROTECTION · SALES',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.grey.withValues(alpha: 0.9),
                      letterSpacing: 4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: 200,
                    child: AnimatedBuilder(
                      animation: _progressCtrl,
                      builder: (_, __) => LinearProgressIndicator(
                        value: _progressCtrl.value,
                        minHeight: 2,
                        backgroundColor: AppColors.blackCard,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            right: 20,
            bottom: 20,
            child: OwlMark(size: 44, opacity: 0.12),
          ),
        ],
      ),
    );
  }
}
