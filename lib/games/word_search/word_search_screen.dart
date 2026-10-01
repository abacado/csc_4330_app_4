import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/arcade_controller.dart';
import '../../core/game_definition.dart';
import '../../core/game_result.dart';
import '../../theme/arcade_theme.dart';
import '../../widgets/game_scaffold.dart';
import 'word_search_board.dart';
import 'word_search_engine.dart';

class WordSearchScreen extends StatefulWidget {
  const WordSearchScreen({super.key, required this.controller, this.newPuzzle});
  final ArcadeController controller;

  /// Overrides puzzle generation, e.g. to supply a fixed grid in tests.
  final WordSearchPuzzle Function()? newPuzzle;
  @override
  State<WordSearchScreen> createState() => _WordSearchScreenState();
}

class _WordSearchScreenState extends State<WordSearchScreen> {
  static final _game = gameById('word_search');
  late WordSearchEngine _engine = _freshEngine();
  String _resultId = const Uuid().v4();
  int? _anchor;
  String _message = 'Tap the first letter of a word.';

  WordSearchEngine _freshEngine() =>
      WordSearchEngine(widget.newPuzzle?.call() ?? WordSearchPuzzle.generate());

  void _tap(int cell) {
    final anchor = _anchor;
    if (anchor == null) {
      setState(() {
        _anchor = cell;
        _message = 'Now tap the last letter.';
      });
      return;
    }
    if (anchor == cell) {
      setState(() {
        _anchor = null;
        _message = 'Selection cleared. Tap the first letter of a word.';
      });
      return;
    }
    final result = _engine.select(anchor, cell);
    setState(() {
      _anchor = null;
      _message = switch (result) {
        SelectionResult.found =>
          _engine.isComplete
              ? 'You found every word!'
              : 'Found ${_engine.found.last.word}!',
        SelectionResult.alreadyFound => 'You already found that one.',
        SelectionResult.notAWord => 'Not a word on the list. Try again.',
        SelectionResult.notAStraightLine =>
          'Words run in straight lines across, down, or diagonally.',
      };
    });
    if (result == SelectionResult.found && _engine.isComplete) {
      unawaited(
        widget.controller.recordResult(
          GameResult(
            id: _resultId,
            gameId: 'word_search',
            outcome: 'completed',
            mode: 'solo',
            completedAt: DateTime.now(),
          ),
        ),
      );
    }
  }

  Future<void> _restart() async {
    if (!_engine.isComplete && _engine.found.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a new puzzle?'),
          content: const Text('The words you found here will be cleared.'),
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
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _engine = _freshEngine();
      _resultId = const Uuid().v4();
      _anchor = null;
      _message = 'Tap the first letter of a word.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = _engine.puzzle;
    final complete = _engine.isComplete;
    return GameScaffold(
      game: _game,
      onRestart: _restart,
      child: Column(
        children: [
          Text(
            'THEME • ${puzzle.theme.toUpperCase()}',
            style: TextStyle(color: _game.color, letterSpacing: 3),
          ),
          const SizedBox(height: 12),
          Text(
            _message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            '${_engine.found.length} of ${puzzle.words.length} found',
            style: const TextStyle(color: arcadeMuted),
          ),
          const SizedBox(height: 20),
          WordSearchBoard(
            engine: _engine,
            anchor: _anchor,
            onTapCell: complete ? null : _tap,
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final word in puzzle.words)
                Chip(
                  label: Text(
                    word,
                    style: TextStyle(
                      decoration: _engine.isFound(word)
                          ? TextDecoration.lineThrough
                          : null,
                      color: _engine.isFound(word) ? arcadeMuted : Colors.white,
                    ),
                  ),
                  avatar: _engine.isFound(word)
                      ? Icon(Icons.check, size: 16, color: _game.color)
                      : null,
                ),
            ],
          ),
          if (complete) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.replay),
              label: const Text('New puzzle'),
            ),
          ],
        ],
      ),
    );
  }
}
