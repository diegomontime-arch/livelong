import 'package:flutter/material.dart';

import 'package:hitlook/data/models/lead.dart';

Color leadStatusColor(LeadStatus status) => switch (status) {
      LeadStatus.newLead => const Color(0xFFD4AF37),
      LeadStatus.contacted => const Color(0xFFF39C12),
      LeadStatus.followUp => const Color(0xFF3498DB),
      LeadStatus.closed => const Color(0xFF2ECC71),
      LeadStatus.lost => const Color(0xFF888888),
    };
