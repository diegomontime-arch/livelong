import 'package:hitlook/data/models/lead.dart';
import 'package:hitlook/data/models/seller.dart';

/// Aggregated lead counts for admin dashboards.
class SellerMetrics {
  const SellerMetrics({
    required this.total,
    required this.newLeads,
    required this.contacted,
    required this.closed,
    this.followUp = 0,
    this.lost = 0,
  });

  const SellerMetrics.empty()
      : total = 0,
        newLeads = 0,
        contacted = 0,
        closed = 0,
        followUp = 0,
        lost = 0;

  final int total;
  final int newLeads;
  final int contacted;
  final int closed;
  final int followUp;
  final int lost;

  static SellerMetrics fromLeads(List<Lead> leads) {
    var newLeads = 0;
    var contacted = 0;
    var followUp = 0;
    var closed = 0;
    var lost = 0;

    for (final lead in leads) {
      switch (lead.status) {
        case LeadStatus.newLead:
          newLeads++;
        case LeadStatus.contacted:
          contacted++;
        case LeadStatus.followUp:
          followUp++;
        case LeadStatus.closed:
          closed++;
        case LeadStatus.lost:
          lost++;
      }
    }

    return SellerMetrics(
      total: leads.length,
      newLeads: newLeads,
      contacted: contacted,
      followUp: followUp,
      closed: closed,
      lost: lost,
    );
  }

  static Map<String, SellerMetrics> bySeller(List<Lead> leads) {
    final grouped = <String, List<Lead>>{};
    for (final lead in leads) {
      grouped.putIfAbsent(lead.sellerId, () => []).add(lead);
    }
    return grouped.map((id, list) => MapEntry(id, SellerMetrics.fromLeads(list)));
  }
}

/// Seller row model for the admin dashboard list.
class SellerWithMetrics {
  const SellerWithMetrics({required this.seller, required this.metrics});

  final Seller seller;
  final SellerMetrics metrics;

  String publicLink(String baseUrl) {
    final slug = seller.slug ?? seller.id;
    final normalized = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$normalized/a/$slug';
  }
}
