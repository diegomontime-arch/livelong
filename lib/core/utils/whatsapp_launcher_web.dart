import 'dart:html' as html;

import 'package:flutter/foundation.dart';

/// Safari iOS — must run synchronously on the user tap (no await before this).
bool openWhatsAppInBrowser(String url) {
  try {
    final anchor = html.AnchorElement(href: url)
      ..target = '_blank'
      ..rel = 'noopener noreferrer';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    debugPrint('[WhatsApp] anchor.click OK');
    return true;
  } catch (e) {
    debugPrint('[WhatsApp] anchor.click failed: $e');
  }

  try {
    html.window.open(url, '_blank');
    debugPrint('[WhatsApp] window.open OK');
    return true;
  } catch (e) {
    debugPrint('[WhatsApp] window.open failed: $e');
    return false;
  }
}
