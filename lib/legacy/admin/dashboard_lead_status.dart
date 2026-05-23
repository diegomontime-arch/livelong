import 'package:flutter/material.dart';

import 'package:hitlook/legacy/screens/language_screen.dart';

class DashboardLeadStatusOption {
  const DashboardLeadStatusOption(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;
}

const leadStatusOptions = [
  DashboardLeadStatusOption('novo', 'Novo', AppColors.gold),
  DashboardLeadStatusOption('contatado', 'Contatado', Color(0xFFF39C12)),
  DashboardLeadStatusOption('fechado', 'Fechado', Color(0xFF2ECC71)),
  DashboardLeadStatusOption('perdido', 'Perdido', Color(0xFF888888)),
];

String normalizeLeadStatus(String? raw) {
  final s = (raw ?? 'novo').toString().toLowerCase().trim();
  if (s == 'new') return 'novo';
  const valid = {'novo', 'contatado', 'fechado', 'perdido'};
  if (valid.contains(s)) return s;
  return 'novo';
}

DashboardLeadStatusOption dashboardLeadStatusMeta(String status) {
  return leadStatusOptions.firstWhere(
    (o) => o.value == status,
    orElse: () => leadStatusOptions.first,
  );
}
