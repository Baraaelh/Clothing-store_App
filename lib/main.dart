import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/app_settings.dart';
import 'core/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies(settings: const AppSettings());
  runApp(const AnaqaApp());
}
