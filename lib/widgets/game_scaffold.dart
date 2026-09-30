import 'package:flutter/material.dart';

import '../core/game_definition.dart';
import '../theme/arcade_theme.dart';

class GameScaffold extends StatelessWidget {
  const GameScaffold({
    super.key,
    required this.game,
    required this.child,
    this.onRestart,
  });
  final GameDefinition game;
  final Widget child;
  final VoidCallback? onRestart;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(game.name),
      actions: [
        IconButton(
          tooltip: 'How to play',
          icon: const Icon(Icons.help_outline),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('How to play ${game.name}'),
              content: Text(game.instructions),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ],
            ),
          ),
        ),
        if (onRestart != null)
          IconButton(
            tooltip: 'Restart game',
            onPressed: onRestart,
            icon: const Icon(Icons.refresh_rounded),
          ),
        const SizedBox(width: 8),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class GameStarter extends StatelessWidget {
  const GameStarter({super.key, required this.game});
  final GameDefinition game;
  @override
  Widget build(BuildContext context) => GameScaffold(
    game: game,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(game.icon, size: 88, color: game.color),
        const SizedBox(height: 28),
        Text(
          'A new challenge is loading',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          '${game.name} is coming soon. In the meantime, grab a friend for a round of Tic-Tac-Toe.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: arcadeMuted, height: 1.6),
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to the arcade'),
        ),
      ],
    ),
  );
}
