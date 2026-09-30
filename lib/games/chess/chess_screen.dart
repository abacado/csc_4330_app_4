import 'package:flutter/material.dart';

import '../../core/game_definition.dart';
import '../../widgets/game_scaffold.dart';

class ChessScreen extends StatelessWidget {
  const ChessScreen({super.key});
  @override
  Widget build(BuildContext context) => GameStarter(game: gameById('chess'));
}
