import 'package:flutter/material.dart';

import '../../core/game_result.dart';
import '../../theme/arcade_theme.dart';
import 'chess_board.dart';
import 'chess_engine.dart';

/// Steps through the FEN snapshots recorded for a finished chess game.
class ChessReplayScreen extends StatefulWidget {
  const ChessReplayScreen({super.key, required this.result});
  final GameResult result;

  @override
  State<ChessReplayScreen> createState() => _ChessReplayScreenState();
}

class _ChessReplayScreenState extends State<ChessReplayScreen> {
  int _ply = 0;
  List<String> get _fens => widget.result.moves!;
  int get _lastPly => _fens.length - 1;

  void _goTo(int ply) => setState(() => _ply = ply.clamp(0, _lastPly));

  @override
  Widget build(BuildContext context) {
    final engine = ChessEngine.fromFen(_fens[_ply]);
    return Scaffold(
      appBar: AppBar(title: const Text('Game review')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _ply == 0
                        ? 'Starting position'
                        : 'Ply $_ply of $_lastPly · ${engine.turn == 'w' ? 'White' : 'Black'} to move',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ChessBoard(
                    board: engine.board,
                    onTap: null,
                    checkSquare: engine.isCheck
                        ? engine.board.indexOf(engine.turn == 'w' ? 'K' : 'k')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: _ply.toDouble(),
                    min: 0,
                    max: _lastPly.toDouble(),
                    divisions: _lastPly == 0 ? null : _lastPly,
                    label: '$_ply',
                    onChanged: (value) => _goTo(value.round()),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        tooltip: 'First move',
                        onPressed: _ply == 0 ? null : () => _goTo(0),
                        icon: const Icon(Icons.skip_previous_rounded),
                      ),
                      IconButton(
                        tooltip: 'Previous move',
                        onPressed: _ply == 0 ? null : () => _goTo(_ply - 1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      IconButton(
                        tooltip: 'Next move',
                        onPressed: _ply == _lastPly
                            ? null
                            : () => _goTo(_ply + 1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                      IconButton(
                        tooltip: 'Last move',
                        onPressed: _ply == _lastPly
                            ? null
                            : () => _goTo(_lastPly),
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                    ],
                  ),
                  Text(
                    widget.result.outcome == 'win'
                        ? 'You won this game.'
                        : widget.result.outcome == 'loss'
                        ? 'You lost this game.'
                        : widget.result.outcome == 'draw'
                        ? 'This game ended in a draw.'
                        : 'This game finished.',
                    style: const TextStyle(color: arcadeMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
