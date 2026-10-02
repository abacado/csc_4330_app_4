import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:csc_4330_app_4/games/game_2048/game_2048_engine.dart';

/// Number of non-empty cells on the board.
int tileCount(Game2048Engine engine) =>
    engine.tiles.where((t) => t != 0).length;

/// Checks one [Game2048Engine.slideLine] call: the resulting line and score.
void expectSlide(List<int> line, List<int> expected, int gained) {
  final (result, points) = Game2048Engine.slideLine(line);
  expect(result, expected);
  expect(points, gained);
}

void main() {
  group('slideLine', () {
    test('Packs tiles toward the leading edge without merging unequal ones', () {
      expectSlide([0, 2, 0, 4], [2, 4, 0, 0], 0);
      expectSlide([2, 4, 8, 16], [2, 4, 8, 16], 0);
    });

    test('Merges a pair and scores the merged value', () {
      expectSlide([2, 0, 0, 2], [4, 0, 0, 0], 4);
    });

    test('Each tile merges at most once per move', () {
      expectSlide([2, 2, 2, 2], [4, 4, 0, 0], 8);
      expectSlide([2, 2, 4, 0], [4, 4, 0, 0], 4);
      expectSlide([4, 4, 8, 8], [8, 16, 0, 0], 24);
    });

    test('With three equal tiles, the pair nearest the edge merges', () {
      expectSlide([2, 2, 2, 0], [4, 2, 0, 0], 4);
      expectSlide([0, 2, 2, 2], [4, 2, 0, 0], 4);
    });
  });

  group('move', () {
    // A single pair in the top row, placed so every direction moves it.
    final start = [
      0, 2, 2, 0, //
      0, 0, 0, 0, //
      0, 0, 0, 0, //
      0, 0, 0, 0, //
    ];

    test('Left and right merge along rows toward that side', () {
      final left = Game2048Engine.fromTiles(start, random: Random(1));
      expect(left.move(SlideDirection.left), isTrue);
      expect(left.tileAt(0, 0), 4);
      expect(left.score, 4);

      final right = Game2048Engine.fromTiles(start, random: Random(1));
      expect(right.move(SlideDirection.right), isTrue);
      expect(right.tileAt(0, 3), 4);
      expect(right.score, 4);
    });

    test('Up and down slide along columns toward that side', () {
      final tiles = [
        0, 0, 0, 0, //
        2, 0, 0, 0, //
        2, 0, 0, 0, //
        4, 0, 0, 0, //
      ];
      final up = Game2048Engine.fromTiles(tiles, random: Random(1));
      expect(up.move(SlideDirection.up), isTrue);
      expect([up.tileAt(0, 0), up.tileAt(1, 0)], [4, 4]);
      expect(up.score, 4);

      final down = Game2048Engine.fromTiles(tiles, random: Random(1));
      expect(down.move(SlideDirection.down), isTrue);
      expect([down.tileAt(2, 0), down.tileAt(3, 0)], [4, 4]);
      expect(down.score, 4);
    });

    test('A move that changes the board spawns exactly one new tile', () {
      final engine = Game2048Engine.fromTiles(start, random: Random(3));
      engine.move(SlideDirection.left); // two tiles merge into one
      expect(tileCount(engine), 2);
      expect(engine.moves, 1);
    });

    test('A move that changes nothing is rejected and spawns nothing', () {
      final tiles = [
        2, 4, 0, 0, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
      ];
      final engine = Game2048Engine.fromTiles(tiles, random: Random(1));
      expect(engine.move(SlideDirection.left), isFalse);
      expect(engine.move(SlideDirection.up), isFalse);
      expect(engine.tiles, tiles);
      expect(engine.moves, 0);
      expect(engine.hasProgress, isFalse);
    });
  });

  group('game state', () {
    test('A new game starts with two tiles of 2 or 4 and no score', () {
      for (var seed = 0; seed < 20; seed++) {
        final engine = Game2048Engine(random: Random(seed));
        expect(tileCount(engine), 2);
        expect(engine.tiles.where((t) => t != 0), everyElement(anyOf(2, 4)));
        expect(engine.score, 0);
        expect(engine.isGameOver, isFalse);
      }
    });

    test('Reaching 2048 is a win', () {
      final engine = Game2048Engine.fromTiles([
        1024, 1024, 0, 0, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
      ], random: Random(1));
      expect(engine.isWon, isFalse);
      engine.move(SlideDirection.left);
      expect(engine.isWon, isTrue);
      expect(engine.highestTile, 2048);
      expect(engine.score, 2048);
    });

    test('A full board with no equal neighbors is game over', () {
      final engine = Game2048Engine.fromTiles([
        2, 4, 2, 4, //
        4, 2, 4, 2, //
        2, 4, 2, 4, //
        4, 2, 4, 2, //
      ]);
      expect(engine.isGameOver, isTrue);
      for (final direction in SlideDirection.values) {
        expect(engine.move(direction), isFalse);
      }
    });

    test('A full board with a vertical pair is not game over', () {
      final engine = Game2048Engine.fromTiles([
        2, 4, 2, 4, //
        2, 8, 4, 2, //
        8, 4, 2, 4, //
        4, 2, 4, 2, //
      ], random: Random(1));
      expect(engine.isGameOver, isFalse);
      expect(engine.move(SlideDirection.left), isFalse);
      expect(engine.move(SlideDirection.up), isTrue);
      expect(engine.tileAt(0, 0), 4);
    });

    test('Rejects layouts with the wrong size or non-power-of-two tiles', () {
      expect(() => Game2048Engine.fromTiles([2, 4]), throwsArgumentError);
      expect(
        () => Game2048Engine.fromTiles([3, ...List.filled(15, 0)]),
        throwsArgumentError,
      );
    });
  });
}
