import 'package:flutter/material.dart';

import '../../core/game_definition.dart';
import '../../widgets/game_scaffold.dart';

class SudokuScreen extends StatelessWidget {
  const SudokuScreen({super.key});
  @override
  Widget build(BuildContext context) => GameStarter(game: gameById('sudoku'));
}
