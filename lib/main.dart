import 'package:flutter/material.dart';

import 'package:hitlook/app.dart';
import 'package:hitlook/core/bootstrap.dart';

Future<void> main() async {
  await bootstrap();
  runApp(const HitLookApp());
}
