import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/arcade_controller.dart';
import '../../core/game_definition.dart';
import '../../core/game_result.dart';
import '../../theme/arcade_theme.dart';
import '../../widgets/game_scaffold.dart';
import 'chess_bot.dart';
import 'chess_board.dart';
import 'chess_engine.dart';
import 'chess_online_room_screen.dart';

class ChessScreen extends StatefulWidget {
  const ChessScreen({super.key, required this.controller});
  final ArcadeController controller;
  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  static const _bot = ChessBot();
  ChessEngine _engine = ChessEngine.initial();
  bool _vsBot = false;
  bool _botThinking = false;
  int? _selected;
  Set<int> _targets = {};
  String _resultId = const Uuid().v4();

  bool get _humansTurn => !(_vsBot && _engine.turn == 'b');

  void _setMode(bool vsBot) {
    if (vsBot == _vsBot) return;
    setState(() {
      _vsBot = vsBot;
      _engine = ChessEngine.initial();
      _selected = null;
      _targets = {};
      _resultId = const Uuid().v4();
    });
  }

  Future<void> _tap(int square) async {
    if (_botThinking || !_humansTurn || _engine.isFinished) return;
    final piece = _engine.board[square];
    final ownPiece = piece.isNotEmpty && ChessEngine.colorOf(piece) == _engine.turn;
    if (_selected == null) {
      if (ownPiece) {
        setState(() {
          _selected = square;
          _targets = _engine.movesFrom(square).map((m) => m.to).toSet();
        });
      }
      return;
    }
    if (square == _selected) {
      setState(() {
        _selected = null;
        _targets = {};
      });
      return;
    }
    if (_targets.contains(square)) {
      await _applyMove(_selected!, square);
      return;
    }
    setState(() {
      if (ownPiece) {
        _selected = square;
        _targets = _engine.movesFrom(square).map((m) => m.to).toSet();
      } else {
        _selected = null;
        _targets = {};
      }
    });
  }

  Future<void> _applyMove(int from, int to) async {
    final needsPromotion = _engine
        .movesFrom(from)
        .any((m) => m.to == to && m.promotion != null);
    String? promotion;
    if (needsPromotion) {
      promotion = await askPromotionChoice(context, _engine.turn == 'w' ? 'white' : 'black');
      if (promotion == null || !mounted) return;
    }
    if (!_engine.makeMove(from, to, promotion: promotion)) return;
    setState(() {
      _selected = null;
      _targets = {};
    });
    await _afterMove();
  }

  Future<void> _afterMove() async {
    if (_engine.isFinished) {
      await _recordResult();
      return;
    }
    if (_vsBot && _engine.turn == 'b') {
      setState(() => _botThinking = true);
      final move = await _bot.chooseMove(_engine);
      if (!mounted) return;
      if (move != null) _engine.applyMove(move);
      setState(() => _botThinking = false);
      if (_engine.isFinished) await _recordResult();
    }
  }

  Future<void> _recordResult() async {
    final outcome = _engine.isDraw
        ? 'draw'
        : _vsBot
        ? (_engine.winner == 'w' ? 'win' : 'loss')
        : 'completed';
    unawaited(
      widget.controller.recordResult(
        GameResult(
          id: _resultId,
          gameId: 'chess',
          outcome: outcome,
          mode: 'local',
          completedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _restart() async {
    if (!_engine.isFinished && _engine.toFen() != kChessInitialFen) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a fresh game?'),
          content: const Text('This unfinished game will be cleared.'),
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
      _engine = ChessEngine.initial();
      _selected = null;
      _targets = {};
      _botThinking = false;
      _resultId = const Uuid().v4();
    });
  }

  String _statusText() {
    if (_engine.isCheckmate) {
      return '${_engine.winner == 'w' ? 'White' : 'Black'} wins by checkmate!';
    }
    if (_engine.isStalemate) return 'Stalemate — it’s a draw.';
    if (_engine.isDraw) return 'Draw.';
    if (_botThinking) return 'Bot is thinking…';
    final mover = _engine.turn == 'w' ? 'White' : 'Black';
    return _engine.isCheck ? '$mover is in check' : '$mover to move';
  }

  @override
  Widget build(BuildContext context) => GameScaffold(
    game: gameById('chess'),
    onRestart: _restart,
    child: Column(
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Pass & Play'),
              icon: Icon(Icons.people_alt_outlined),
            ),
            ButtonSegment(
              value: true,
              label: Text('vs Bot'),
              icon: Icon(Icons.smart_toy_outlined),
            ),
          ],
          selected: {_vsBot},
          onSelectionChanged: (selection) => _setMode(selection.first),
        ),
        const SizedBox(height: 16),
        Text(
          _statusText(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        ChessBoard(
          board: _engine.board,
          selected: _selected,
          legalTargets: _targets,
          checkSquare: _engine.isCheck
              ? _engine.board.indexOf(_engine.turn == 'w' ? 'K' : 'k')
              : null,
          onTap: _engine.isFinished || _botThinking || !_humansTurn
              ? null
              : (square) => unawaited(_tap(square)),
        ),
        const SizedBox(height: 20),
        if (_engine.isFinished)
          FilledButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.replay),
            label: const Text('New game'),
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
                              ChessOnlineRoomScreen(controller: widget.controller),
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
