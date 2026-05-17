import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'language_screen.dart';
import 'agent_login_screen.dart';
import 'agent_setup_screen.dart';
import 'agent_dashboard_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final isAgentRoute = state.uri.path.startsWith('/agent') ||
        state.uri.path == '/login' ||
        state.uri.path == '/dashboard' ||
        state.uri.path == '/perfil';

    if (state.uri.path == '/dashboard' && !isLoggedIn) {
      return '/login';
    }
    if (state.uri.path == '/perfil' && !isLoggedIn) {
      return '/login';
    }
    return null;
  },
  routes: [
    // Rota raiz — tela de seleção de idioma
    GoRoute(
      path: '/',
      builder: (context, state) => const LanguageScreen(),
    ),

    // Rota do agente — link personalizado
    // Ex: hitlook-app.web.app/a/m4life
    GoRoute(
      path: '/a/:agentId',
      builder: (context, state) {
        final agentId = state.pathParameters['agentId'] ?? 'default';
        return LanguageScreen(agentId: agentId);
      },
    ),

    // Login do agente
    GoRoute(
      path: '/login',
      builder: (context, state) => const AgentLoginScreen(),
    ),

    // Painel do agente
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const AgentDashboardScreen(),
    ),

    // Perfil do agente
    GoRoute(
      path: '/perfil',
      builder: (context, state) => const AgentSetupScreen(),
    ),
  ],
);
