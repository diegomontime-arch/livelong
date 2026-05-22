import 'dart:html' as html;

import 'package:flutter/foundation.dart';

/// Safari iOS fallback when [url_launcher] returns false (user-gesture path).
bool openWhatsAppInBrowser(String url) {
  try {
    html.window.open(url, '_blank');
    debugPrint('[WhatsApp] window.open OK');
    return true;
  } catch (e) {
    debugPrint('[WhatsApp] window.open failed: $e');
    return false;
  }
}
