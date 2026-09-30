import 'package:flutter/material.dart';

import 'core/arcade_controller.dart';
import 'screens/arcade_home.dart';
import 'theme/arcade_theme.dart';

class PocketArcadeApp extends StatelessWidget {
  const PocketArcadeApp({super.key, required this.controller});
  final ArcadeController controller;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pocket Arcade',
    debugShowCheckedModeBanner: false,
    theme: buildArcadeTheme(),
    home: ArcadeHome(controller: controller),
  );
}
