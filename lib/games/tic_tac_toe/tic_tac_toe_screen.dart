import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/arcade_controller.dart';
import '../../core/game_definition.dart';
import '../../core/game_result.dart';
import '../../theme/arcade_theme.dart';
import '../../widgets/game_scaffold.dart';
import 'online_room_screen.dart';
import 'tic_tac_toe_board.dart';
import 'tic_tac_toe_engine.dart';

class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key, required this.controller});
  final ArcadeController controller;
  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  TicTacToeEngine _game = TicTacToeEngine();
  String _resultId = const Uuid().v4();

  void _play(int cell) {
    if (!_game.play(cell)) return;
    setState(() {});
    if (_game.isFinished) {
      unawaited(
        widget.controller.recordResult(
          GameResult(
            id: _resultId,
            gameId: 'tic_tac_toe',
            outcome: _game.isDraw ? 'draw' : 'completed',
            mode: 'local',
            completedAt: DateTime.now(),
          ),
        ),
      );
    }
  }

  Future<void> _restart() async {
    if (!_game.isFinished && _game.board.any((cell) => cell.isNotEmpty)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a fresh round?'),
          content: const Text('This unfinished round will be cleared.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep playing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restart'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _game = TicTacToeEngine();
      _resultId = const Uuid().v4();
    });
  }

  @override
  Widget build(BuildContext context) => GameScaffold(
    game: gameById('tic_tac_toe'),
    onRestart: _restart,
    child: Column(
      children: [
        const Text(
          'PASS & PLAY',
          style: TextStyle(color: arcadeMint, letterSpacing: 3),
        ),
        const SizedBox(height: 12),
        Text(
          _game.winner != null
              ? '${_game.winner} takes the round!'
              : _game.isDraw
              ? 'A perfect stalemate.'
              : '${_game.turn} — your move',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Two players. One device.',
          style: TextStyle(color: arcadeMuted),
        ),
        const SizedBox(height: 26),
        TicTacToeBoard(
          board: _game.board,
          onMove: _game.isFinished ? null : _play,
        ),
        const SizedBox(height: 24),
        if (_game.isFinished)
          FilledButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.replay),
            label: const Text('One more round'),
          ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => Column(
            children: [
              OutlinedButton.icon(
                onPressed: widget.controller.status == CloudStatus.connected
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              OnlineRoomScreen(controller: widget.controller),
                        ),
                      )
                    : null,
                icon: const Icon(Icons.public),
                label: const Text('Play with a room code'),
              ),
              if (widget.controller.status != CloudStatus.connected)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Online rooms unlock when the cloud is connected.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: arcadeMuted, fontSize: 12),
                  ),
                ),
              if (widget.controller.notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    widget.controller.notice!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: arcadeMuted),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
