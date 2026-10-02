import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/arcade_controller.dart';
import '../../core/game_definition.dart';
import '../../core/game_result.dart';
import '../../theme/arcade_theme.dart';
import '../../widgets/game_scaffold.dart';
import 'sudoku_board.dart';
import 'sudoku_engine.dart';

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key, required this.controller, this.newPuzzle});
  final ArcadeController controller;

  /// Overrides puzzle generation, e.g. to supply a fixed grid in tests.
  final SudokuPuzzle Function(SudokuDifficulty difficulty)? newPuzzle;
  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  static final _game = gameById('sudoku');
  SudokuDifficulty _difficulty = SudokuDifficulty.easy;
  late SudokuEngine _engine = _freshEngine();
  String _resultId = const Uuid().v4();
  int? _selected;
  bool _notesMode = false;

  SudokuEngine _freshEngine() => SudokuEngine(
    widget.newPuzzle?.call(_difficulty) ?? SudokuPuzzle.generate(_difficulty),
  );

  void _enter(int digit) {
    final cell = _selected;
    if (cell == null) return;
    if (digit == 0 && _engine.values[cell] == 0) {
      if (_engine.clearNotes(cell)) setState(() {});
      return;
    }
    if (_notesMode && digit != 0) {
      if (_engine.toggleNote(cell, digit)) setState(() {});
      return;
    }
    if (!_engine.setValue(cell, digit)) return;
    setState(() {});
    if (_engine.isSolved) {
      _selected = null;
      unawaited(
        widget.controller.recordResult(
          GameResult(
            id: _resultId,
            gameId: 'sudoku',
            outcome: 'completed',
            mode: 'solo',
            completedAt: DateTime.now(),
          ),
        ),
      );
    }
  }

  Future<bool> _confirmDiscard() async {
    if (_engine.isSolved || !_engine.hasProgress) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a new puzzle?'),
        content: const Text('Your progress on this puzzle will be cleared.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('New puzzle'),
          ),
        ],
      ),
    );
    return confirmed == true && mounted;
  }

  Future<void> _restart([SudokuDifficulty? difficulty]) async {
    if (!await _confirmDiscard()) return;
    setState(() {
      _difficulty = difficulty ?? _difficulty;
      _engine = _freshEngine();
      _resultId = const Uuid().v4();
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final solved = _engine.isSolved;
    final conflicts = _engine.conflicts;
    return GameScaffold(
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
            solved
                ? 'Puzzle solved!'
                : conflicts.isNotEmpty
                ? 'Something repeats — check the red squares.'
                : _selected == null
                ? 'Pick a square to begin.'
                : _notesMode
                ? 'Jot down a possible number.'
                : 'Choose a number.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 18),
          SegmentedButton<SudokuDifficulty>(
            segments: [
              for (final d in SudokuDifficulty.values)
                ButtonSegment(value: d, label: Text(d.label)),
            ],
            selected: {_difficulty},
            showSelectedIcon: false,
            onSelectionChanged: (choice) => _restart(choice.single),
          ),
          const SizedBox(height: 20),
          SudokuBoard(
            engine: _engine,
            selected: _selected,
            conflicts: conflicts,
            accent: _game.color,
            onSelect: solved
                ? null
                : (cell) => setState(() => _selected = cell),
          ),
          const SizedBox(height: 20),
          if (solved)
            FilledButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.replay),
              label: const Text('New puzzle'),
            )
          else
            SudokuNumberPad(
              engine: _engine,
              onDigit: _selected == null || _engine.isGiven(_selected!)
                  ? null
                  : _enter,
              notesMode: _notesMode,
              onToggleNotes: () => setState(() => _notesMode = !_notesMode),
            ),
          const SizedBox(height: 12),
          const Text(
            'Gray numbers are clues and cannot be changed. '
            'Turn on Notes to pencil in numbers you are unsure of.',
            textAlign: TextAlign.center,
            style: TextStyle(color: arcadeMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
