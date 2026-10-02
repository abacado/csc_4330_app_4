import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:csc_4330_app_4/games/minesweeper/minesweeper_engine.dart';

void main() {
  test('The first reveal is never a mine, even when tapping a mine-dense corner', () {
    for (var seed = 0; seed < 20; seed++) {
      final engine = MinesweeperEngine(
        MinesweeperDifficulty.easy,
        random: Random(seed),
      );
      expect(engine.reveal(0), isTrue);
      expect(engine.isMine(0), isFalse);
      expect(engine.isLoss, isFalse);
    }
  });

  test('Revealing a mine ends the game as a loss', () {
    final engine = MinesweeperEngine.fixed(
      difficulty: MinesweeperDifficulty.easy,
      mines: {10},
    );
    expect(engine.reveal(10), isTrue);
    expect(engine.isLoss, isTrue);
    expect(engine.isFinished, isTrue);
    expect(engine.reveal(0), isFalse); // game is over
  });

  test('Revealing every safe square wins without touching a mine', () {
    final engine = MinesweeperEngine.fixed(
      difficulty: MinesweeperDifficulty.easy,
      mines: {0},
    );
    for (var cell = 1; cell < engine.cellCount; cell++) {
      engine.reveal(cell);
    }
    expect(engine.isWin, isTrue);
    expect(engine.isLoss, isFalse);
  });

  test('Revealing a zero-count cell flood-fills the whole open region', () {
    // All mines bunched in the bottom-right corner leaves the rest of the
    // 8x8 board open, so one reveal cascades across nearly the entire board.
    final mines = {
      for (var r = 6; r < 8; r++) for (var c = 6; c < 8; c++) r * 8 + c,
    };
    final engine = MinesweeperEngine.fixed(
      difficulty: MinesweeperDifficulty.easy,
      mines: mines,
    );
    engine.reveal(0);
    expect(engine.isRevealed(0), isTrue);
    expect(engine.isRevealed(7), isTrue); // top-right corner
    expect(engine.isRevealed(7 * 8), isTrue); // bottom-left corner
    for (final mine in mines) {
      expect(engine.isRevealed(mine), isFalse);
    }
    // A boundary cell touching the mine cluster is revealed with a nonzero
    // count, but does not propagate the flood any further through mines.
    expect(engine.isRevealed(5 * 8 + 5), isTrue);
    expect(engine.adjacentMines(5 * 8 + 5), greaterThan(0));
  });

  test('Flags toggle on hidden cells and are blocked on revealed ones', () {
    final engine = MinesweeperEngine.fixed(
      difficulty: MinesweeperDifficulty.easy,
      mines: {63},
    );
    expect(engine.toggleFlag(1), isTrue);
    expect(engine.isFlagged(1), isTrue);
    expect(engine.minesRemaining, engine.mineCount - 1);
    expect(engine.toggleFlag(1), isTrue);
    expect(engine.isFlagged(1), isFalse);

    engine.reveal(0);
    expect(engine.toggleFlag(0), isFalse); // already revealed
  });

  test('A flagged cell cannot be revealed until unflagged', () {
    final engine = MinesweeperEngine.fixed(
      difficulty: MinesweeperDifficulty.easy,
      mines: {63},
    );
    engine.toggleFlag(1);
    expect(engine.reveal(1), isFalse);
    expect(engine.isRevealed(1), isFalse);
    engine.toggleFlag(1);
    expect(engine.reveal(1), isTrue);
  });
}
