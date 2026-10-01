import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:csc_4330_app_4/games/word_search/word_search_engine.dart';

final sample = WordSearchPuzzle.fromRows(
  ['CATSX', 'XDOGX', 'XXXXX', 'BIRDX', 'XXXXX'],
  ['CAT', 'DOG', 'BIRD'],
);

/// Finds [word] anywhere in [puzzle] in any of the eight directions.
bool appearsIn(WordSearchPuzzle puzzle, String word) {
  final n = puzzle.size;
  for (var start = 0; start < n * n; start++) {
    for (final (dr, dc) in directions) {
      final r = start ~/ n + dr * (word.length - 1);
      final c = start % n + dc * (word.length - 1);
      if (r < 0 || r >= n || c < 0 || c >= n) continue;
      if (puzzle.textOf(puzzle.line(start, r * n + c)!) == word) return true;
    }
  }
  return false;
}

void main() {
  test('Generated grids hide every listed word', () {
    for (var seed = 0; seed < 25; seed++) {
      final puzzle = WordSearchPuzzle.generate(random: Random(seed));
      expect(puzzle.grid.length, 100);
      expect(puzzle.words.length, 8);
      expect(puzzle.grid.every((l) => RegExp(r'^[A-Z]$').hasMatch(l)), isTrue);
      for (final word in puzzle.words) {
        expect(appearsIn(puzzle, word), isTrue, reason: '$word, seed $seed');
      }
    }
  });

  test('Words are found forwards and backwards', () {
    final game = WordSearchEngine(sample);
    expect(game.select(6, 8), SelectionResult.found); // DOG
    expect(game.select(2, 0), SelectionResult.found); // CAT, reversed
    expect(game.found.map((f) => f.word), ['DOG', 'CAT']);
    expect(game.found.last.cells, [2, 1, 0]);
  });

  test('Diagonal lines are supported', () {
    final puzzle = WordSearchPuzzle.fromRows(['AXX', 'XBX', 'XXC'], ['ABC']);
    expect(puzzle.line(0, 8), [0, 4, 8]);
    expect(WordSearchEngine(puzzle).select(8, 0), SelectionResult.found);
  });

  test('Duplicate, wrong, and bent selections are rejected', () {
    final game = WordSearchEngine(sample);
    expect(game.select(6, 8), SelectionResult.found);
    expect(game.select(8, 6), SelectionResult.alreadyFound);
    expect(game.select(0, 3), SelectionResult.notAWord); // CATS
    expect(game.select(0, 7), SelectionResult.notAStraightLine);
    expect(game.found.length, 1);
    expect(game.isComplete, isFalse);
  });

  test('Finding every word completes the puzzle', () {
    final game = WordSearchEngine(sample)
      ..select(0, 2)
      ..select(6, 8)
      ..select(15, 18);
    expect(game.isComplete, isTrue);
  });
}
