import 'package:flutter/material.dart';

import '../../core/game_definition.dart';
import '../../widgets/game_scaffold.dart';

class CheckersScreen extends StatelessWidget {
  const CheckersScreen({super.key});
  @override
  Widget build(BuildContext context) => GameStarter(game: gameById('checkers'));
}
