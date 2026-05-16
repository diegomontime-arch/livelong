import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'language_screen.dart';
import 'agent_login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const HitLookApp());
}

class HitLookApp extends StatelessWidget {
  const HitLookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HitLook',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _gridCtrl;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleIn;
  late Animation<double> _pulse;
  late Animation<double> _gridFade;

  @override
  void initState() {
    super.initState();
    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _gridCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );
    _scaleIn = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _gridFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _gridCtrl,
        curve: const Interval(0, 0.5, curve: Curves.easeIn),
      ),
    );
    _mainCtrl.forward();
    _gridCtrl.forward();

    Future.delayed(const Duration(milliseconds: 3400), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LanguageScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _pulseCtrl.dispose();
    _gridCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _gridFade,
            builder: (_, __) => Opacity(
              opacity: _gridFade.value * 0.1,
              child: CustomPaint(
                painter: _GridPainter(),
                size: MediaQuery.of(context).size,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFD4AF37)
                          .withOpacity(0.07 * _pulse.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: ScaleTransition(
                scale: _scaleIn,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D0D0D),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withOpacity(0.35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD4AF37)
                                  .withOpacity(0.12 * _pulse.value),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.shield_outlined,
                            size: 36,
                            color: Color(0xFFD4AF37),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'HIT',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 6,
                            ),
                          ),
                          TextSpan(
                            text: 'LOOK',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFD4AF37),
                              letterSpacing: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 20,
                          height: 1,
                          color: const Color(0xFF8B7420).withOpacity(0.4),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'AI · SALES · INTELLIGENCE',
                          style: TextStyle(
                            fontSize: 9,
                            color: const Color(0xFF888888).withOpacity(0.6),
                            letterSpacing: 3,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 20,
                          height: 1,
                          color: const Color(0xFF8B7420).withOpacity(0.4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 52),
                    _LoadingBar(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 28,
            right: 24,
            child: FadeTransition(
              opacity: _fadeIn,
              child: Text(
                'v1.0',
                style: TextStyle(
                  fontSize: 10,
                  color: const Color(0xFF555555).withOpacity(0.35),
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBar extends StatefulWidget {
  @override
  State<_LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<_LoadingBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _prog;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _prog = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _label(double v) {
    if (v < 0.33) return 'INITIALIZING';
    if (v < 0.66) return 'LOADING AI';
    return 'READY';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _prog,
      builder: (_, __) => Column(
        children: [
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _prog.value,
                backgroundColor:
                    const Color(0xFF8B7420).withOpacity(0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFD4AF37)),
                minHeight: 2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _label(_prog.value),
            style: TextStyle(
              fontSize: 9,
              color: const Color(0xFF555555).withOpacity(0.5),
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..strokeWidth = 0.4;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter old) => false;
}
