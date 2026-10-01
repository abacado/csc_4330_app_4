import 'dart:math';

/// The eight straight-line directions as (row step, column step).
const directions = <(int, int)>[
  (0, 1),
  (1, 0),
  (1, 1),
  (-1, 1),
  (0, -1),
  (-1, 0),
  (-1, -1),
  (1, -1),
];

const themes = <String, List<String>>{
  'Animals': [
    'TIGER', 'OTTER', 'ZEBRA', 'KOALA', 'PANDA', 'EAGLE', //
    'SHARK', 'CAMEL', 'MOOSE', 'GECKO', 'LLAMA', 'BISON',
  ],
  'Space': [
    'PLANET', 'COMET', 'ORBIT', 'GALAXY', 'NEBULA', 'ROCKET', //
    'METEOR', 'SATURN', 'LUNAR', 'STAR', 'MARS', 'VENUS',
  ],
  'Food': [
    'PIZZA', 'TACO', 'MANGO', 'BAGEL', 'PASTA', 'SUSHI', //
    'WAFFLE', 'NOODLE', 'LEMON', 'CHEESE', 'PEACH', 'CURRY',
  ],
  'Coding': [
    'DART', 'WIDGET', 'BUTTON', 'SERVER', 'COMMIT', 'BRANCH', //
    'DEBUG', 'ARRAY', 'CLASS', 'LOOP', 'STRING', 'MERGE',
  ],
  'Ocean': [
    'CORAL', 'WHALE', 'TIDE', 'SQUID', 'REEF', 'WAVE', //
    'SHELL', 'KELP', 'CRAB', 'ANCHOR', 'PEARL', 'DOLPHIN',
  ],
};

class WordSearchPuzzle {
  WordSearchPuzzle({
    required this.size,
    required List<String> grid,
    required List<String> words,
    this.theme = 'Custom',
  }) : grid = List.unmodifiable(grid),
       words = List.unmodifiable(words) {
    if (grid.length != size * size) {
      throw ArgumentError('Grid must have size × size letters.');
    }
  }

  /// Builds a puzzle from rows of letters, e.g. for tests.
  factory WordSearchPuzzle.fromRows(
    List<String> rows,
    List<String> words, {
    String theme = 'Custom',
  }) => WordSearchPuzzle(
    size: rows.length,
    grid: rows.join().toUpperCase().split(''),
    words: [for (final w in words) w.toUpperCase()],
    theme: theme,
  );

  /// Hides [count] words from a random theme in a fresh grid. Words may run in
  /// any of the eight directions and may share matching letters.
  factory WordSearchPuzzle.generate({
    int size = 10,
    int count = 8,
    Random? random,
  }) {
    final rng = random ?? Random();
    final theme = themes.keys.elementAt(rng.nextInt(themes.length));
    final pool = themes[theme]!.where((w) => w.length <= size).toList();
    while (true) {
      final grid = List.filled(size * size, '');
      final placed = <String>[];
      for (final word in List.of(pool)..shuffle(rng)) {
        if (placed.length == count) break;
        if (_place(grid, size, word, rng)) placed.add(word);
      }
      if (placed.length < min(count, pool.length)) continue;
      const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      for (var i = 0; i < grid.length; i++) {
        if (grid[i].isEmpty) grid[i] = alphabet[rng.nextInt(alphabet.length)];
      }
      return WordSearchPuzzle(
        size: size,
        grid: grid,
        words: placed..sort(),
        theme: theme,
      );
    }
  }

  final int size;
  final List<String> grid, words;
  final String theme;

  /// Cells from [start] to [end] inclusive, or null if they are not on one
  /// horizontal, vertical, or diagonal line.
  List<int>? line(int start, int end) {
    final r0 = start ~/ size, c0 = start % size;
    final dr = end ~/ size - r0, dc = end % size - c0;
    if (dr != 0 && dc != 0 && dr.abs() != dc.abs()) return null;
    final steps = max(dr.abs(), dc.abs());
    return [
      for (var i = 0; i <= steps; i++)
        (r0 + dr.sign * i) * size + c0 + dc.sign * i,
    ];
  }

  String textOf(List<int> cells) => cells.map((c) => grid[c]).join();
}

bool _place(List<String> grid, int size, String word, Random rng) {
  for (var attempt = 0; attempt < 200; attempt++) {
    final (dr, dc) = directions[rng.nextInt(directions.length)];
    final r = rng.nextInt(size), c = rng.nextInt(size);
    final endR = r + dr * (word.length - 1), endC = c + dc * (word.length - 1);
    if (endR < 0 || endR >= size || endC < 0 || endC >= size) continue;
    final cells = [
      for (var i = 0; i < word.length; i++) (r + dr * i) * size + c + dc * i,
    ];
    var fits = true;
    for (var i = 0; i < word.length && fits; i++) {
      fits = grid[cells[i]].isEmpty || grid[cells[i]] == word[i];
    }
    if (!fits) continue;
    for (var i = 0; i < word.length; i++) {
      grid[cells[i]] = word[i];
    }
    return true;
  }
  return false;
}

enum SelectionResult { found, alreadyFound, notAWord, notAStraightLine }

class FoundWord {
  const FoundWord(this.word, this.cells);
  final String word;
  final List<int> cells;
}

class WordSearchEngine {
  WordSearchEngine(this.puzzle);
  final WordSearchPuzzle puzzle;
  final List<FoundWord> _found = [];

  List<FoundWord> get found => List.unmodifiable(_found);
  bool isFound(String word) => _found.any((f) => f.word == word);
  bool get isComplete => _found.length == puzzle.words.length;

  /// Checks the line from [start] to [end]. Words read in either direction.
  SelectionResult select(int start, int end) {
    final cells = puzzle.line(start, end);
    if (cells == null) return SelectionResult.notAStraightLine;
    final text = puzzle.textOf(cells);
    final reversed = text.split('').reversed.join();
    final word = puzzle.words
        .where((w) => w == text || w == reversed)
        .firstOrNull;
    if (word == null) return SelectionResult.notAWord;
    if (isFound(word)) return SelectionResult.alreadyFound;
    _found.add(FoundWord(word, cells));
    return SelectionResult.found;
  }
}
