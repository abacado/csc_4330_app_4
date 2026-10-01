import 'package:flutter_test/flutter_test.dart';
import 'package:csc_4330_app_4/games/chess/chess_engine.dart';

void main() {
  test('Initial position has the standard 20 legal moves for White', () {
    final game = ChessEngine.initial();
    expect(game.turn, 'w');
    expect(game.allLegalMoves(), hasLength(20));
    expect(game.isFinished, isFalse);
  });

  test('Illegal moves are rejected and the turn does not change', () {
    final game = ChessEngine.initial();
    expect(game.makeMove(0, 16), isFalse); // rook blocked by its own pawn
    expect(game.makeMove(12, 44), isFalse); // pawn cannot leap four squares
    expect(game.turn, 'w');
  });

  test('Legal pawn double-move and reply alternate turns', () {
    final game = ChessEngine.initial();
    expect(game.makeMove(12, 28), isTrue); // e2-e4
    expect(game.turn, 'b');
    expect(game.makeMove(52, 36), isTrue); // e7-e5
    expect(game.turn, 'w');
  });

  test('En passant capture removes the passed pawn', () {
    final game = ChessEngine.initial();
    expect(game.makeMove(12, 28), isTrue); // e2-e4
    expect(game.makeMove(48, 40), isTrue); // a7-a6
    expect(game.makeMove(28, 36), isTrue); // e4-e5
    expect(game.makeMove(51, 35), isTrue); // d7-d5
    expect(game.makeMove(36, 43), isTrue); // e5xd6 en passant
    expect(game.board[43], 'P');
    expect(game.board[35], '');
    expect(game.board[36], '');
  });

  test('Castling moves the rook and clears castling rights', () {
    final game = ChessEngine.fromFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
    expect(game.makeMove(4, 6), isTrue); // White king-side castle
    expect(game.board[6], 'K');
    expect(game.board[5], 'R');
    expect(game.board[7], '');
    expect(game.castling, 'kq');
  });

  test('Pawn reaching the last rank must promote', () {
    final game = ChessEngine.fromFen('8/P6k/8/8/8/8/7p/7K w - - 0 1');
    expect(game.makeMove(48, 56, promotion: 'Q'), isTrue);
    expect(game.board[56], 'Q');
  });

  test("Fool's mate is detected as checkmate for Black", () {
    final game = ChessEngine.initial();
    expect(game.makeMove(13, 21), isTrue); // f2-f3
    expect(game.makeMove(52, 36), isTrue); // e7-e5
    expect(game.makeMove(14, 30), isTrue); // g2-g4
    expect(game.makeMove(59, 31), isTrue); // Qd8-h4#
    expect(game.isCheckmate, isTrue);
    expect(game.isFinished, isTrue);
    expect(game.winner, 'b');
  });

  test('A known position is detected as stalemate', () {
    final game = ChessEngine.fromFen('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
    expect(game.isCheck, isFalse);
    expect(game.isStalemate, isTrue);
    expect(game.isDraw, isTrue);
    expect(game.winner, isNull);
  });

  test('FEN round-trips through parse and export', () {
    const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    expect(ChessEngine.fromFen(fen).toFen(), fen);
  });

  test('Move encode/decode round-trips square names', () {
    const move = ChessMove(12, 28);
    final code = ChessEngine.encodeMove(move);
    final decoded = ChessEngine.decodeMove(code);
    expect(decoded.from, 12);
    expect(decoded.to, 28);
  });
}
