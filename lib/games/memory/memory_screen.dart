import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/arcade_controller.dart';
import '../../core/game_definition.dart';
import '../../core/game_result.dart';
import '../../theme/arcade_theme.dart';
import '../../widgets/game_scaffold.dart';
import 'memory_board.dart';
import 'memory_engine.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({
    super.key,
    required this.controller,
    this.newEngine,
    this.mismatchDelay = const Duration(milliseconds: 900),
  });
  final ArcadeController controller;

  /// Overrides deck creation, e.g. to supply a fixed layout in tests.
  final MemoryEngine Function()? newEngine;

  /// How long a mismatched pair stays visible before flipping back.
  final Duration mismatchDelay;

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  static final _game = gameById('memory');
  late MemoryEngine _engine = _freshEngine();
  String _resultId = const Uuid().v4();
  Timer? _hideTimer;

  MemoryEngine _freshEngine() =>
      widget.newEngine?.call() ?? MemoryEngine(pairs: memorySymbols.length);

  void _flip(int index) {
    if (!_engine.flip(index)) return;
    setState(() {});
    if (_engine.hasMismatch) {
      _hideTimer = Timer(widget.mismatchDelay, () {
        if (mounted) setState(_engine.hideMismatch);
      });
    } else if (_engine.isComplete) {
      unawaited(
        widget.controller.recordResult(
          GameResult(
            id: _resultId,
            gameId: 'memory',
            outcome: 'completed',
            mode: 'solo',
            completedAt: DateTime.now(),
          ),
        ),
      );
    }
  }

  Future<bool> _confirmDiscard() async {
    if (_engine.isComplete || !_engine.hasProgress) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a new game?'),
        content: const Text('The cards will be reshuffled.'),
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
    _hideTimer?.cancel();
    setState(() {
      _engine = _freshEngine();
      _resultId = const Uuid().v4();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final complete = _engine.isComplete;
    return GameScaffold(
      game: _game,
      onRestart: _restart,
      child: Column(
        children: [
          Text('SOLO', style: TextStyle(color: _game.color, letterSpacing: 3)),
          const SizedBox(height: 12),
          Text(
            complete
                ? 'All pairs found in ${_engine.moves} moves!'
                : _engine.hasMismatch
                ? 'Not a match. Remember them!'
                : 'Flip two cards to find a pair.',
            key: const ValueKey('memory-status'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'MOVES ${_engine.moves}   •   PAIRS '
            '${_engine.matchedPairs}/${_engine.pairCount}',
            key: const ValueKey('memory-score'),
            style: const TextStyle(color: arcadeMuted, letterSpacing: 2),
          ),
          const SizedBox(height: 20),
          MemoryBoard(
            engine: _engine,
            accent: _game.color,
            onFlip: complete ? null : _flip,
          ),
          if (complete) ...[
            const SizedBox(height: 20),
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
