import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/app_settings.dart';
import 'core/database/dev_seeder.dart';
import 'core/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await configureDependencies(settings: const AppSettings());
  await DevSeeder(sl(), sl()).seedIfNeeded();

  runApp(const AnaqaApp());
}
