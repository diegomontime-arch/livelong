// Smoke test básico para o HitLook app.

import 'package:flutter_test/flutter_test.dart';

import 'package:hitlook/main.dart';

void main() {
  testWidgets('HitLook app smoke test', (WidgetTester tester) async {
    // Apenas verifica que o app é construído sem erro.
    await tester.pumpWidget(const HitLookApp());
  });
}
