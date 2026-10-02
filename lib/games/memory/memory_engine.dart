import 'dart:math';

/// Pure rules for Memory: a shuffled deck of pairs, flipping two cards per
/// move, keeping matches face up, and counting moves. No widgets or timers;
/// the screen decides when to call [hideMismatch].
class MemoryEngine {
  /// Builds a shuffled deck with [pairs] distinct symbols, each appearing
  /// exactly twice. Symbols are numbered 0 to pairs - 1.
  factory MemoryEngine({int pairs = 8, Random? random}) {
    if (pairs < 1) {
      throw ArgumentError.value(pairs, 'pairs', 'Need at least one pair.');
    }
    final symbols = [
      for (var s = 0; s < pairs; s++) ...[s, s],
    ]..shuffle(random ?? Random());
    return MemoryEngine.fromSymbols(symbols);
  }

  /// Uses a fixed card layout, e.g. in tests. Every symbol must appear
  /// exactly twice.
  MemoryEngine.fromSymbols(List<int> symbols)
    : symbols = List.unmodifiable(symbols),
      _matched = List.filled(symbols.length, false) {
    final counts = <int, int>{};
    for (final s in symbols) {
      counts[s] = (counts[s] ?? 0) + 1;
    }
    if (symbols.isEmpty || counts.values.any((c) => c != 2)) {
      throw ArgumentError('Every symbol must appear exactly twice.');
    }
  }

  /// The symbol on each card, by position.
  final List<int> symbols;
  final List<bool> _matched;
  final List<int> _revealed = [];
  int _moves = 0;

  int get cardCount => symbols.length;
  int get pairCount => symbols.length ~/ 2;

  /// A move is one pair of cards turned over.
  int get moves => _moves;
  int get matchedPairs => _matched.where((m) => m).length ~/ 2;
  bool get isComplete => _matched.every((m) => m);

  /// True once some cards have been flipped, so restarting would lose work.
  bool get hasProgress => _moves > 0 || _revealed.isNotEmpty;

  /// Two unmatched cards are face up and must be hidden before the next
  /// flip. The screen should lock input while this is true.
  bool get hasMismatch => _revealed.length == 2;

  bool isMatched(int index) => _matched[index];
  bool isFaceUp(int index) => _matched[index] || _revealed.contains(index);

  /// Turns a card face up. Returns false for an illegal flip: out of range,
  /// already face up or matched, or while a mismatch is waiting to hide.
  bool flip(int index) {
    if (index < 0 || index >= cardCount) return false;
    if (hasMismatch || isFaceUp(index)) return false;
    _revealed.add(index);
    if (_revealed.length == 2) {
      _moves++;
      final [a, b] = _revealed;
      if (symbols[a] == symbols[b]) {
        _matched[a] = true;
        _matched[b] = true;
        _revealed.clear();
      }
    }
    return true;
  }

  /// Turns a mismatched pair back face down.
  void hideMismatch() {
    if (hasMismatch) _revealed.clear();
  }
}
