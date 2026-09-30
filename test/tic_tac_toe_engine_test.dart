import 'package:flutter_test/flutter_test.dart';
import 'package:csc_4330_app_4/games/tic_tac_toe/tic_tac_toe_engine.dart';

void main() {
  test('X starts and legal moves alternate', () {
    final game = TicTacToeEngine();
    expect(game.turn, 'X');
    expect(game.play(4), isTrue);
    expect(game.board[4], 'X');
    expect(game.turn, 'O');
    expect(game.play(0), isTrue);
    expect(game.board[0], 'O');
  });
  test('Occupied and out-of-bounds cells cannot change the turn', () {
    final game = TicTacToeEngine()..play(0);
    for (final cell in [0, -1, 9]) {
      expect(game.play(cell), isFalse);
    }
    expect(game.turn, 'O');
  });
  final lines = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];
  for (final mark in ['X', 'O']) {
    for (final line in lines) {
      test('$mark wins on $line', () {
        final board = List.filled(9, '');
        for (final cell in line) {
          board[cell] = mark;
        }
        expect(TicTacToeEngine.winnerOf(board), mark);
      });
    }
  }
  test('Draw ends the round and prevents more moves', () {
    final game = TicTacToeEngine();
    for (final cell in [0, 1, 2, 4, 3, 5, 7, 6, 8]) {
      expect(game.play(cell), isTrue);
    }
    expect(game.isDraw, isTrue);
    expect(game.isFinished, isTrue);
    expect(game.play(0), isFalse);
  });
  test('Win ends the round immediately', () {
    final game = TicTacToeEngine();
    for (final cell in [0, 3, 1, 4, 2]) {
      game.play(cell);
    }
    expect(game.winner, 'X');
    expect(game.play(5), isFalse);
    expect(game.board[5], '');
  });
}
