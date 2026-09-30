import 'package:flutter/material.dart';

import '../../core/game_definition.dart';
import '../../widgets/game_scaffold.dart';

class MemoryScreen extends StatelessWidget {
  const MemoryScreen({super.key});
  @override
  Widget build(BuildContext context) => GameStarter(game: gameById('memory'));
}
