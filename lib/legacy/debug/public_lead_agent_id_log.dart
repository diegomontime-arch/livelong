import 'package:flutter/foundation.dart';

/// Temporary debug logs for public lead [agentId] propagation. Remove when verified.
void logPublicLeadAgentId(String screen, String agentId) {
  debugPrint('[HitLook:publicLead] $screen → agentId="$agentId"');
}
