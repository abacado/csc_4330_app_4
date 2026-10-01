import 'package:flutter/foundation.dart';

import 'chess_engine.dart';

const _pieceValues = {'P': 100, 'N': 320, 'B': 330, 'R': 500, 'Q': 900, 'K': 0};

class _BotRequest {
  const _BotRequest(this.fen, this.depth);
  final String fen;
  final int depth;
}

/// Plays moves for one side using a depth-limited negamax search, run on a
/// background isolate so the UI thread never blocks while "thinking".
class ChessBot {
  const ChessBot({this.depth = 2});
  final int depth;

  Future<ChessMove?> chooseMove(ChessEngine engine) async {
    final encoded = await compute(_bestMoveFor, _BotRequest(engine.toFen(), depth));
    return encoded == null ? null : ChessEngine.decodeMove(encoded);
  }
}

String? _bestMoveFor(_BotRequest request) {
  final engine = ChessEngine.fromFen(request.fen);
  final moves = engine.allLegalMoves();
  if (moves.isEmpty) return null;
  ChessMove best = moves.first;
  var bestScore = -1 << 30;
  var alpha = -1 << 30;
  const beta = 1 << 30;
  for (final move in moves) {
    final next = engine.clone()..applyMove(move);
    final score = -_negamax(next, request.depth - 1, -beta, -alpha);
    if (score > bestScore) {
      bestScore = score;
      best = move;
    }
    if (score > alpha) alpha = score;
  }
  return ChessEngine.encodeMove(best);
}

int _negamax(ChessEngine position, int depth, int alpha, int beta) {
  if (position.isCheckmate) return -99000 - depth;
  if (position.isDraw) return 0;
  if (depth <= 0) return _evaluate(position);
  var best = -1 << 30;
  for (final move in position.allLegalMoves()) {
    final next = position.clone()..applyMove(move);
    final score = -_negamax(next, depth - 1, -beta, -alpha);
    if (score > best) best = score;
    if (best > alpha) alpha = best;
    if (alpha >= beta) break;
  }
  return best;
}

int _evaluate(ChessEngine position) {
  var score = 0;
  for (final piece in position.board) {
    if (piece.isEmpty) continue;
    final value = _pieceValues[piece.toUpperCase()] ?? 0;
    score += piece == piece.toUpperCase() ? value : -value;
  }
  return position.turn == 'w' ? score : -score;
}
