import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/arcade_controller.dart';
import 'services/local_store.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final controller = ArcadeController(
    store: LocalStore(preferences),
    cloud: SupabaseService.fromEnvironment(),
  );
  runApp(PocketArcadeApp(controller: controller));
  unawaited(controller.connect());
}
