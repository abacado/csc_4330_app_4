import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:csc_4330_app_4/games/sudoku/sudoku_engine.dart';

const classic =
    '530070000600195000098000060800060003400803001'
    '700020006060000280000419005000080079';
const classicSolution =
    '534678912672195348198342567859761423426853791'
    '713924856961537284287419635345286179';

List<int> digits(String s) => [for (final c in s.split('')) int.parse(c)];

bool isValidSolution(List<int> grid) {
  for (var cell = 0; cell < 81; cell++) {
    if (grid[cell] < 1 || grid[cell] > 9) return false;
    if (peers[cell].any((p) => grid[p] == grid[cell])) return false;
  }
  return true;
}

void main() {
  test('Parsing a known puzzle finds its unique solution', () {
    final puzzle = SudokuPuzzle.parse(classic);
    expect(puzzle.solution, digits(classicSolution));
    expect(puzzle.clueCount, 30);
  });

  test('Puzzles without exactly one solution are rejected', () {
    expect(() => SudokuPuzzle.parse('0' * 81), throwsArgumentError);
    expect(countSolutions(digits('55${'0' * 79}')), 0);
  });

  for (final difficulty in SudokuDifficulty.values) {
    test('Generated ${difficulty.label} puzzles are valid and unique', () {
      for (var seed = 0; seed < 3; seed++) {
        final puzzle = SudokuPuzzle.generate(difficulty, random: Random(seed));
        expect(isValidSolution(puzzle.solution), isTrue);
        expect(countSolutions(puzzle.givens), 1);
        for (var cell = 0; cell < 81; cell++) {
          if (puzzle.givens[cell] != 0) {
            expect(puzzle.givens[cell], puzzle.solution[cell]);
          }
        }
        expect(puzzle.clueCount, lessThanOrEqualTo(difficulty.targetClues + 6));
      }
    });
  }

  test('Clues cannot be changed and invalid input is ignored', () {
    final game = SudokuEngine(SudokuPuzzle.parse(classic));
    expect(game.setValue(0, 1), isFalse); // clue
    expect(game.setValue(2, 10), isFalse);
    expect(game.setValue(81, 4), isFalse);
    expect(game.values[0], 5);
    expect(game.hasProgress, isFalse);
  });

  test('Repeated numbers are reported as conflicts and can be erased', () {
    final game = SudokuEngine(SudokuPuzzle.parse(classic));
    expect(game.setValue(2, 5), isTrue); // row 1 already has a 5
    expect(game.conflicts, containsAll([0, 2]));
    expect(game.hasProgress, isTrue);
    expect(game.setValue(2, 0), isTrue);
    expect(game.conflicts, isEmpty);
  });

  test('Notes toggle on empty cells and clear when a number is placed', () {
    final game = SudokuEngine(SudokuPuzzle.parse(classic));
    expect(game.toggleNote(0, 1), isFalse); // clue
    expect(game.toggleNote(2, 0), isFalse);
    expect(game.toggleNote(2, 4), isTrue);
    expect(game.toggleNote(2, 1), isTrue);
    expect(game.toggleNote(3, 4), isTrue); // same row as cell 2
    expect(game.toggleNote(3, 6), isTrue);
    expect(game.notesAt(2), {1, 4});
    expect(game.hasProgress, isTrue);

    expect(game.toggleNote(2, 1), isTrue);
    expect(game.notesAt(2), {4});

    expect(game.setValue(2, 4), isTrue);
    expect(game.notesAt(2), isEmpty);
    expect(game.notesAt(3), {6}); // the placed 4 is crossed off its peers
    expect(game.toggleNote(2, 7), isFalse); // cell is filled

    expect(game.clearNotes(3), isTrue);
    expect(game.clearNotes(3), isFalse);
    expect(game.notesAt(3), isEmpty);
  });

  test('Filling in the solution completes the puzzle and locks it', () {
    final puzzle = SudokuPuzzle.parse(classic);
    final game = SudokuEngine(puzzle);
    for (var cell = 0; cell < 81; cell++) {
      if (!game.isGiven(cell)) game.setValue(cell, puzzle.solution[cell]);
    }
    expect(game.isSolved, isTrue);
    expect(game.conflicts, isEmpty);
    expect(game.setValue(2, 0), isFalse);
  });
}
