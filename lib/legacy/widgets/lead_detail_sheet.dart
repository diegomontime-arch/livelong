import 'package:flutter/material.dart';

import 'package:hitlook/core/utils/whatsapp_utils.dart';
import 'package:hitlook/legacy/admin/dashboard_lead_status.dart';
import 'package:hitlook/legacy/screens/language_screen.dart';
import 'package:hitlook/legacy/widgets/flow_ux.dart';

/// Bottom sheet de detalhes do lead (evita tela branca no iPhone).
class LeadDetailSheet extends StatefulWidget {
  const LeadDetailSheet({
    super.key,
    required this.lead,
    required this.onStatusChanged,
  });

  final Map<String, dynamic> lead;
  final ValueChanged<String> onStatusChanged;

  @override
  State<LeadDetailSheet> createState() => _LeadDetailSheetState();
}

class _LeadDetailSheetState extends State<LeadDetailSheet> {
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = normalizeLeadStatus(widget.lead['status'] as String?);
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    final nome = leadDisplayName(lead);
    final telefone = leadDisplayPhone(lead);
    final scoreInt = leadDisplayScore(lead);
    final lang = lead['lang']?.toString() ?? 'pt';
    final nascimento = lead['nascimento']?.toString() ?? '';
    final answers = lead['answers'];
    final meta = dashboardLeadStatusMeta(_status);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.45),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$scoreInt%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                      if (telefone.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          telefone,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.greyLight,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        formatLeadDate(lead['createdAt']),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.grey.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'STATUS',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.greyLight,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.2),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _status,
                  dropdownColor: AppColors.blackCard,
                  icon: Icon(Icons.expand_more, color: meta.color),
                  style: TextStyle(
                    color: meta.color,
                    fontWeight: FontWeight.w600,
                  ),
                  items: leadStatusOptions
                      .map(
                        (o) => DropdownMenuItem(
                          value: o.value,
                          child: Text(
                            o.label,
                            style: TextStyle(color: o.color),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null || v == _status) return;
                    setState(() => _status = v);
                    widget.onStatusChanged(v);
                  },
                ),
              ),
            ),
            if (nascimento.isNotEmpty) ...[
              const SizedBox(height: 16),
              _LeadDetailRow(
                icon: Icons.cake_outlined,
                label: 'Nascimento',
                value: nascimento,
              ),
            ],
            _LeadDetailRow(
              icon: Icons.language,
              label: 'Idioma',
              value: lang.toUpperCase(),
            ),
            if (answers is Map && answers.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Respostas',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.greyLight,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              ...answers.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${e.key}: ${e.value}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.whiteWarm,
                    ),
                  ),
                ),
              ),
            ],
            if (telefone.isNotEmpty) ...[
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    openWhatsApp(
                      phone: telefone,
                      message: buildLeadWhatsAppMessage(
                        lang: lang,
                        score: scoreInt,
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('Abrir WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeadDetailRow extends StatelessWidget {
  const _LeadDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.gold.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.greyLight,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
