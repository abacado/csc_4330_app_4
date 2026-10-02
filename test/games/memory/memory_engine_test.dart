import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:csc_4330_app_4/games/memory/memory_engine.dart';

void main() {
  // Cards 0 and 2 match, 1 and 3 match.
  MemoryEngine twoPairs() => MemoryEngine.fromSymbols([0, 1, 0, 1]);

  test('A new deck has every symbol exactly twice', () {
    final engine = MemoryEngine(pairs: 8, random: Random(1));
    expect(engine.cardCount, 16);
    for (var s = 0; s < 8; s++) {
      expect(engine.symbols.where((x) => x == s).length, 2);
    }
    expect(engine.moves, 0);
    expect(engine.hasProgress, isFalse);
  });

  test('Decks are shuffled', () {
    final a = MemoryEngine(pairs: 8, random: Random(1)).symbols;
    final b = MemoryEngine(pairs: 8, random: Random(2)).symbols;
    expect(a, isNot(equals(b)));
  });

  test('Layouts without exact pairs are rejected', () {
    expect(() => MemoryEngine.fromSymbols([0, 0, 1]), throwsArgumentError);
    expect(() => MemoryEngine.fromSymbols([]), throwsArgumentError);
  });

  test('A matching pair stays face up and counts one move', () {
    final engine = twoPairs();
    expect(engine.flip(0), isTrue);
    expect(engine.isFaceUp(0), isTrue);
    expect(engine.flip(2), isTrue);
    expect(engine.isMatched(0), isTrue);
    expect(engine.isMatched(2), isTrue);
    expect(engine.hasMismatch, isFalse);
    expect(engine.moves, 1);
    expect(engine.matchedPairs, 1);
  });

  test('A mismatch locks input until it is hidden', () {
    final engine = twoPairs();
    engine.flip(0);
    engine.flip(1);
    expect(engine.hasMismatch, isTrue);
    expect(engine.moves, 1);
    expect(engine.flip(2), isFalse, reason: 'input is locked');

    engine.hideMismatch();
    expect(engine.isFaceUp(0), isFalse);
    expect(engine.isFaceUp(1), isFalse);
    expect(engine.flip(2), isTrue);
  });

  test('Illegal flips are rejected', () {
    final engine = twoPairs();
    expect(engine.flip(-1), isFalse);
    expect(engine.flip(4), isFalse);
    engine.flip(0);
    expect(engine.flip(0), isFalse, reason: 'already face up');
    engine.flip(2);
    expect(engine.flip(2), isFalse, reason: 'already matched');
    expect(engine.moves, 1);
  });

  test('Matching every pair completes the game', () {
    final engine = twoPairs();
    engine
      ..flip(0)
      ..flip(2)
      ..flip(1)
      ..flip(3);
    expect(engine.isComplete, isTrue);
    expect(engine.moves, 2);
  });

  test('A fresh engine resets the deck and moves', () {
    final played = twoPairs()
      ..flip(0)
      ..flip(1);
    expect(played.hasProgress, isTrue);
    final fresh = MemoryEngine(pairs: 2, random: Random(3));
    expect(fresh.moves, 0);
    expect(fresh.matchedPairs, 0);
    expect(fresh.isComplete, isFalse);
  });
}
