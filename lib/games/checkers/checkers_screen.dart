import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/arcade_controller.dart';
import '../../core/game_definition.dart';
import '../../core/game_result.dart';
import '../../theme/arcade_theme.dart';
import '../../widgets/game_scaffold.dart';
import 'checkers_board.dart';
import 'checkers_engine.dart';

class CheckersScreen extends StatefulWidget {
  const CheckersScreen({super.key, required this.controller, this.newEngine});
  final ArcadeController controller;

  /// Overrides the starting position, e.g. to supply a fixed board in tests.
  final CheckersEngine Function()? newEngine;

  @override
  State<CheckersScreen> createState() => _CheckersScreenState();
}

class _CheckersScreenState extends State<CheckersScreen> {
  static final _game = gameById('checkers');
  late CheckersEngine _engine = _freshEngine();
  String _resultId = const Uuid().v4();
  int? _selected;
  String? _hint;

  CheckersEngine _freshEngine() => widget.newEngine?.call() ?? CheckersEngine();

  void _tap(int square) {
    if (_engine.isOver) return;
    final selected = _selected;
    if (selected != null && _engine.move(selected, square)) {
      setState(() {
        _selected = _engine.mustContinueFrom;
        _hint = null;
      });
      if (_engine.isOver) _record();
      return;
    }
    if (_engine.mustContinueFrom != null) {
      setState(() => _hint = 'Keep jumping with the highlighted piece.');
      return;
    }
    if (_engine.movesFrom(square).isNotEmpty) {
      setState(() {
        _selected = square;
        _hint = null;
      });
    } else if (_engine.pieceAt(square)?.side == _engine.turn) {
      setState(() {
        _selected = null;
        _hint = _engine.legalMoves.any((m) => m.isJump)
            ? 'A jump is available, and jumps are required.'
            : 'That piece has no moves.';
      });
    }
  }

  void _record() => unawaited(
    widget.controller.recordResult(
      GameResult(
        id: _resultId,
        gameId: 'checkers',
        outcome: 'completed',
        mode: 'local',
        completedAt: DateTime.now(),
      ),
    ),
  );

  Future<bool> _confirmDiscard() async {
    if (_engine.isOver || !_engine.hasProgress) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a new game?'),
        content: const Text('The current game will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('New game'),
          ),
        ],
      ),
    );
    return confirmed == true && mounted;
  }

  Future<void> _restart() async {
    if (!await _confirmDiscard()) return;
    setState(() {
      _engine = _freshEngine();
      _resultId = const Uuid().v4();
      _selected = null;
      _hint = null;
    });
  }

  String get _status {
    final winner = _engine.winner;
    if (winner != null) return '${winner.label} wins!';
    if (_engine.mustContinueFrom != null) {
      return '${_engine.turn.label}: keep jumping!';
    }
    if (_engine.legalMoves.any((m) => m.isJump)) {
      return '${_engine.turn.label} must jump';
    }
    return "${_engine.turn.label}'s turn";
  }

  @override
  Widget build(BuildContext context) {
    final over = _engine.isOver;
    final turnColor = _engine.turn == Side.red ? redPieceColor : arcadeMuted;
    return GameScaffold(
      game: _game,
      onRestart: _restart,
      child: Column(
        children: [
          Text(
            'LOCAL • 2 PLAYERS',
            style: TextStyle(color: _game.color, letterSpacing: 3),
          ),
          const SizedBox(height: 12),
          Text(
            _status,
            key: const ValueKey('checkers-status'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: over ? null : turnColor),
          ),
          const SizedBox(height: 8),
          Text(
            'BLACK ${_engine.pieceCount(Side.black)}   •   '
            'RED ${_engine.pieceCount(Side.red)}',
            key: const ValueKey('checkers-score'),
            style: const TextStyle(color: arcadeMuted, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          CheckersBoard(
            engine: _engine,
            selected: _selected,
            accent: _game.color,
            onTap: over ? null : _tap,
          ),
          const SizedBox(height: 12),
          Text(
            _hint ?? 'Tap a glowing piece, then tap a dot to move.',
            key: const ValueKey('checkers-hint'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: arcadeMuted, fontSize: 12),
          ),
          if (over) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.replay),
              label: const Text('Play again'),
            ),
          ],
        ],
      ),
    );
  }
}
