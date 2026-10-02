import 'package:flutter_test/flutter_test.dart';
import 'package:csc_4330_app_4/games/checkers/checkers_engine.dart';

/// Square index for a row and column (row 0 is Black's back row).
int sq(int row, int col) => row * 8 + col;

const black = Piece(Side.black);
const red = Piece(Side.red);
const blackKing = Piece(Side.black, king: true);

void main() {
  test('The starting position has 12 pieces each and Black moves', () {
    final engine = CheckersEngine();
    expect(engine.pieceCount(Side.black), 12);
    expect(engine.pieceCount(Side.red), 12);
    expect(engine.turn, Side.black);
    expect(engine.legalMoves.length, 7);
    expect(engine.hasProgress, isFalse);
  });

  test('A simple move passes the turn', () {
    final engine = CheckersEngine();
    expect(engine.move(sq(2, 1), sq(3, 0)), isTrue);
    expect(engine.pieceAt(sq(3, 0))?.side, Side.black);
    expect(engine.pieceAt(sq(2, 1)), isNull);
    expect(engine.turn, Side.red);
    expect(engine.hasProgress, isTrue);
  });

  test('Illegal moves are rejected', () {
    final engine = CheckersEngine();
    expect(engine.move(sq(5, 0), sq(4, 1)), isFalse, reason: 'not your turn');
    expect(engine.move(sq(2, 1), sq(3, 1)), isFalse, reason: 'not diagonal');
    expect(engine.move(sq(2, 1), sq(4, 3)), isFalse, reason: 'too far');
    expect(engine.move(sq(3, 0), sq(4, 1)), isFalse, reason: 'empty square');

    final lone = CheckersEngine.fromPieces({sq(3, 2): black, sq(7, 0): red});
    expect(lone.move(sq(3, 2), sq(2, 1)), isFalse, reason: 'men go forward');
    expect(engine.turn, Side.black);
  });

  test('Pieces must start on dark squares', () {
    expect(
      () => CheckersEngine.fromPieces({sq(0, 0): black}),
      throwsArgumentError,
    );
  });

  test('Jumps are mandatory and remove the captured piece', () {
    final engine = CheckersEngine.fromPieces({
      sq(2, 1): black,
      sq(2, 5): black,
      sq(3, 2): red,
      sq(7, 0): red,
    });
    expect(engine.legalMoves.every((m) => m.isJump), isTrue);
    expect(engine.move(sq(2, 5), sq(3, 6)), isFalse, reason: 'must jump');
    expect(engine.move(sq(2, 1), sq(4, 3)), isTrue);
    expect(engine.pieceAt(sq(3, 2)), isNull);
    expect(engine.pieceCount(Side.red), 1);
    expect(engine.turn, Side.red);
  });

  test('A piece that can keep jumping must continue', () {
    final engine = CheckersEngine.fromPieces({
      sq(0, 1): black,
      sq(1, 2): red,
      sq(3, 4): red,
      sq(7, 6): red,
    });
    expect(engine.move(sq(0, 1), sq(2, 3)), isTrue);
    expect(engine.turn, Side.black, reason: 'still jumping');
    expect(engine.mustContinueFrom, sq(2, 3));
    expect(engine.legalMoves.every((m) => m.from == sq(2, 3)), isTrue);

    expect(engine.move(sq(2, 3), sq(4, 5)), isTrue);
    expect(engine.mustContinueFrom, isNull);
    expect(engine.turn, Side.red);
    expect(engine.pieceCount(Side.red), 1);
  });

  test('Reaching the far row crowns a king and ends the move', () {
    final engine = CheckersEngine.fromPieces({
      sq(5, 2): black,
      sq(6, 3): red,
      sq(6, 5): red,
      sq(1, 0): red,
    });
    expect(engine.move(sq(5, 2), sq(7, 4)), isTrue);
    expect(engine.pieceAt(sq(7, 4))?.king, isTrue);
    expect(engine.turn, Side.red, reason: 'crowning ends the turn');
    expect(engine.mustContinueFrom, isNull);
  });

  test('Kings move backward as well as forward', () {
    final engine = CheckersEngine.fromPieces({
      sq(4, 3): blackKing,
      sq(7, 0): red,
    });
    expect(engine.movesFrom(sq(4, 3)).length, 4);
    expect(engine.move(sq(4, 3), sq(3, 2)), isTrue);
  });

  test('Capturing the last piece wins', () {
    final engine = CheckersEngine.fromPieces({sq(2, 1): black, sq(3, 2): red});
    expect(engine.winner, isNull);
    engine.move(sq(2, 1), sq(4, 3));
    expect(engine.pieceCount(Side.red), 0);
    expect(engine.winner, Side.black);
    expect(engine.isOver, isTrue);
  });

  test('A player with no legal moves loses', () {
    final engine = CheckersEngine.fromPieces({
      sq(7, 0): red,
      sq(6, 1): black,
      sq(5, 2): black,
    }, turn: Side.red);
    expect(engine.legalMoves, isEmpty);
    expect(engine.winner, Side.black);
  });
}
