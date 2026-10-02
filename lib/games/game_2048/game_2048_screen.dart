import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../core/arcade_controller.dart';
import '../../core/game_definition.dart';
import '../../core/game_result.dart';
import '../../theme/arcade_theme.dart';
import '../../widgets/game_scaffold.dart';
import 'game_2048_board.dart';
import 'game_2048_engine.dart';

final _keyDirections = {
  LogicalKeyboardKey.arrowLeft: SlideDirection.left,
  LogicalKeyboardKey.arrowRight: SlideDirection.right,
  LogicalKeyboardKey.arrowUp: SlideDirection.up,
  LogicalKeyboardKey.arrowDown: SlideDirection.down,
  LogicalKeyboardKey.keyA: SlideDirection.left,
  LogicalKeyboardKey.keyD: SlideDirection.right,
  LogicalKeyboardKey.keyW: SlideDirection.up,
  LogicalKeyboardKey.keyS: SlideDirection.down,
};

class Game2048Screen extends StatefulWidget {
  const Game2048Screen({super.key, required this.controller, this.newEngine});
  final ArcadeController controller;

  /// Overrides board creation, e.g. to supply a fixed layout in tests.
  final Game2048Engine Function()? newEngine;

  @override
  State<Game2048Screen> createState() => _Game2048ScreenState();
}

class _Game2048ScreenState extends State<Game2048Screen> {
  static final _game = gameById('game_2048');
  late Game2048Engine _engine = _freshEngine();
  late int _best = widget.controller.store.bestScore('game_2048');
  String _resultId = const Uuid().v4();
  bool _recorded = false;

  /// Set when the player chooses to continue past 2048.
  bool _keepGoing = false;

  Game2048Engine _freshEngine() => widget.newEngine?.call() ?? Game2048Engine();

  /// Reached 2048 and has not yet chosen to keep going.
  bool get _showingWin => _engine.isWon && !_keepGoing;
  bool get _locked => _showingWin || _engine.isGameOver;

  void _slide(SlideDirection direction) {
    if (_locked || !_engine.move(direction)) return;
    setState(() {
      if (_engine.score > _best) {
        _best = _engine.score;
        unawaited(widget.controller.store.saveBestScore('game_2048', _best));
      }
    });
    if (_engine.isWon || _engine.isGameOver) _recordResult();
  }

  /// Saves one result per round: a win the first time 2048 appears, or a
  /// loss if the board locks up before that.
  void _recordResult() {
    if (_recorded) return;
    _recorded = true;
    unawaited(
      widget.controller.recordResult(
        GameResult(
          id: _resultId,
          gameId: 'game_2048',
          outcome: _engine.isWon ? 'win' : 'loss',
          mode: 'solo',
          completedAt: DateTime.now(),
        ),
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final direction = _keyDirections[event.logicalKey];
    if (direction == null) return KeyEventResult.ignored;
    _slide(direction);
    return KeyEventResult.handled;
  }

  Future<bool> _confirmDiscard() async {
    if (_locked || !_engine.hasProgress) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a new game?'),
        content: const Text('Your current board and score will be lost.'),
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
      _recorded = false;
      _keepGoing = false;
    });
  }

  String _statusText() {
    if (_showingWin) return 'You made 2048!';
    if (_engine.isGameOver) return 'No moves left.';
    return 'Merge tiles to reach 2048.';
  }

  @override
  Widget build(BuildContext context) => GameScaffold(
    game: _game,
    onRestart: _restart,
    child: Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        children: [
          Text('SOLO', style: TextStyle(color: _game.color, letterSpacing: 3)),
          const SizedBox(height: 12),
          Text(
            _statusText(),
            key: const ValueKey('game-2048-status'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'SCORE ${_engine.score}   •   BEST $_best',
            key: const ValueKey('game-2048-score'),
            style: const TextStyle(color: arcadeMuted, letterSpacing: 2),
          ),
          const SizedBox(height: 20),
          Game2048Board(
            engine: _engine,
            accent: _game.color,
            onSlide: _locked ? null : _slide,
          ),
          const SizedBox(height: 20),
          if (_locked)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (_showingWin)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _keepGoing = true),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Keep going'),
                  ),
                FilledButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.replay),
                  label: const Text('New game'),
                ),
              ],
            ),
          const SizedBox(height: 12),
          const Text(
            'Swipe the board or use the arrow keys to slide every tile. '
            'Matching tiles merge into one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: arcadeMuted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
