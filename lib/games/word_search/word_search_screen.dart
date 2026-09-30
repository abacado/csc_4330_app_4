import 'package:flutter/material.dart';

import '../../core/game_definition.dart';
import '../../widgets/game_scaffold.dart';

class WordSearchScreen extends StatelessWidget {
  const WordSearchScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      GameStarter(game: gameById('word_search'));
}
