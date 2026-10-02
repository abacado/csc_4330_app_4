import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/arcade_controller.dart';
import '../../core/game_definition.dart';
import '../../core/game_result.dart';
import '../../theme/arcade_theme.dart';
import '../../widgets/game_scaffold.dart';
import 'minesweeper_board.dart';
import 'minesweeper_engine.dart';

class MinesweeperScreen extends StatefulWidget {
  const MinesweeperScreen({super.key, required this.controller, this.newEngine});
  final ArcadeController controller;

  /// Overrides engine creation, e.g. to supply deterministic mines in tests.
  final MinesweeperEngine Function(MinesweeperDifficulty difficulty)? newEngine;
  @override
  State<MinesweeperScreen> createState() => _MinesweeperScreenState();
}

class _MinesweeperScreenState extends State<MinesweeperScreen> {
  static final _game = gameById('minesweeper');
  MinesweeperDifficulty _difficulty = MinesweeperDifficulty.easy;
  late MinesweeperEngine _engine = _freshEngine();
  String _resultId = const Uuid().v4();
  Timer? _ticker;
  int _elapsedSeconds = 0;

  MinesweeperEngine _freshEngine() =>
      widget.newEngine?.call(_difficulty) ?? MinesweeperEngine(_difficulty);

  void _startTickerIfNeeded() {
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _engine.isFinished) return;
      setState(() => _elapsedSeconds++);
    });
  }

  void _reveal(int cell) {
    if (!_engine.reveal(cell)) return;
    _startTickerIfNeeded();
    setState(() {});
    if (_engine.isFinished) _recordResult();
  }

  void _flag(int cell) {
    if (!_engine.toggleFlag(cell)) return;
    setState(() {});
  }

  void _recordResult() {
    _ticker?.cancel();
    unawaited(
      widget.controller.recordResult(
        GameResult(
          id: _resultId,
          gameId: 'minesweeper',
          outcome: _engine.isWin ? 'win' : 'loss',
          mode: 'solo',
          completedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    if (_engine.isFinished || !_engine.hasProgress) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a new board?'),
        content: const Text('This unfinished board will be cleared.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('New board'),
          ),
        ],
      ),
    );
    return confirmed == true && mounted;
  }

  Future<void> _restart([MinesweeperDifficulty? difficulty]) async {
    if (!await _confirmDiscard()) return;
    _ticker?.cancel();
    _ticker = null;
    setState(() {
      _difficulty = difficulty ?? _difficulty;
      _engine = _freshEngine();
      _resultId = const Uuid().v4();
      _elapsedSeconds = 0;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _statusText() {
    if (_engine.isWin) return 'Board cleared!';
    if (_engine.isLoss) return 'Boom — that was a mine.';
    return '${_engine.minesRemaining} mines left';
  }

  @override
  Widget build(BuildContext context) => GameScaffold(
    game: _game,
    onRestart: _restart,
    child: Column(
      children: [
        Text(
          'SOLO • ${_difficulty.label.toUpperCase()}',
          style: TextStyle(color: _game.color, letterSpacing: 3),
        ),
        const SizedBox(height: 12),
        Text(
          _statusText(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Time: ${_elapsedSeconds}s',
          style: const TextStyle(color: arcadeMuted),
        ),
        const SizedBox(height: 18),
        SegmentedButton<MinesweeperDifficulty>(
          segments: [
            for (final d in MinesweeperDifficulty.values)
              ButtonSegment(value: d, label: Text(d.label)),
          ],
          selected: {_difficulty},
          showSelectedIcon: false,
          onSelectionChanged: (choice) => unawaited(_restart(choice.single)),
        ),
        const SizedBox(height: 20),
        MinesweeperBoard(
          engine: _engine,
          accent: _game.color,
          onReveal: _engine.isFinished ? null : _reveal,
          onFlag: _engine.isFinished ? null : _flag,
        ),
        const SizedBox(height: 20),
        if (_engine.isFinished)
          FilledButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.replay),
            label: const Text('New board'),
          ),
        const SizedBox(height: 12),
        const Text(
          'Tap a square to reveal it. Long-press a hidden square to flag '
          'it as a mine. Clear every safe square to win.',
          textAlign: TextAlign.center,
          style: TextStyle(color: arcadeMuted, fontSize: 12),
        ),
      ],
    ),
  );
}
