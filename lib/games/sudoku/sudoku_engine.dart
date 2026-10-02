import 'dart:math';

enum SudokuDifficulty {
  easy('Easy', 40),
  medium('Medium', 32),
  hard('Hard', 26);

  const SudokuDifficulty(this.label, this.targetClues);
  final String label;

  /// Clues the generator aims to leave. Harder grids may stop a little above
  /// this when no further clue can be removed without losing uniqueness.
  final int targetClues;
}

/// A puzzle with a single solution. Cells are indexed 0–80, row by row, and
/// 0 means empty.
class SudokuPuzzle {
  SudokuPuzzle({required List<int> givens, required List<int> solution})
    : givens = List.unmodifiable(givens),
      solution = List.unmodifiable(solution) {
    if (givens.length != 81 || solution.length != 81) {
      throw ArgumentError('A Sudoku grid has exactly 81 cells.');
    }
  }

  /// Builds a puzzle from an 81-character string (`0` or `.` for blanks) and
  /// solves it. Throws if the puzzle does not have exactly one solution.
  factory SudokuPuzzle.parse(String cells) {
    final givens = [
      for (final ch in cells.replaceAll(RegExp(r'\s'), '').split(''))
        ch == '.' ? 0 : int.parse(ch),
    ];
    if (countSolutions(givens) != 1) {
      throw ArgumentError('Puzzle must have exactly one solution.');
    }
    return SudokuPuzzle(givens: givens, solution: solve(givens)!);
  }

  /// Creates a fresh random puzzle with a unique solution.
  factory SudokuPuzzle.generate(SudokuDifficulty difficulty, {Random? random}) {
    final rng = random ?? Random();
    final solution = _randomSolution(rng);
    final givens = List.of(solution);
    var clues = 81;
    for (final cell in List.generate(81, (i) => i)..shuffle(rng)) {
      if (clues <= difficulty.targetClues) break;
      final kept = givens[cell];
      givens[cell] = 0;
      if (countSolutions(givens) == 1) {
        clues--;
      } else {
        givens[cell] = kept;
      }
    }
    return SudokuPuzzle(givens: givens, solution: solution);
  }

  final List<int> givens, solution;
  int get clueCount => givens.where((v) => v != 0).length;
}

int rowOf(int cell) => cell ~/ 9;
int colOf(int cell) => cell % 9;
int boxOf(int cell) => rowOf(cell) ~/ 3 * 3 + colOf(cell) ~/ 3;

/// Every other cell sharing a row, column, or box with each cell.
final List<List<int>> peers = List.unmodifiable([
  for (var cell = 0; cell < 81; cell++)
    List<int>.unmodifiable([
      for (var other = 0; other < 81; other++)
        if (other != cell &&
            (rowOf(other) == rowOf(cell) ||
                colOf(other) == colOf(cell) ||
                boxOf(other) == boxOf(cell)))
          other,
    ]),
]);

bool _canPlace(List<int> grid, int cell, int digit) =>
    peers[cell].every((p) => grid[p] != digit);

/// Counts solutions up to [limit] using backtracking on the most constrained
/// empty cell first.
int countSolutions(List<int> grid, {int limit = 2}) {
  final work = List.of(grid);
  for (var cell = 0; cell < 81; cell++) {
    final digit = work[cell];
    if (digit == 0) continue;
    work[cell] = 0;
    final ok = _canPlace(work, cell, digit);
    work[cell] = digit;
    if (!ok) return 0;
  }
  var count = 0;
  void search() {
    if (count >= limit) return;
    var best = -1;
    List<int>? bestOptions;
    for (var cell = 0; cell < 81; cell++) {
      if (work[cell] != 0) continue;
      final options = [
        for (var d = 1; d <= 9; d++)
          if (_canPlace(work, cell, d)) d,
      ];
      if (bestOptions == null || options.length < bestOptions.length) {
        best = cell;
        bestOptions = options;
        if (options.length <= 1) break;
      }
    }
    if (best == -1) {
      count++;
      return;
    }
    for (final d in bestOptions!) {
      work[best] = d;
      search();
      if (count >= limit) break;
    }
    work[best] = 0;
  }

  search();
  return count;
}

/// Returns a solution, or null if the grid cannot be solved.
List<int>? solve(List<int> grid) {
  final work = List.of(grid);
  bool fill(int cell) {
    if (cell == 81) return true;
    if (work[cell] != 0) return fill(cell + 1);
    for (var d = 1; d <= 9; d++) {
      if (_canPlace(work, cell, d)) {
        work[cell] = d;
        if (fill(cell + 1)) return true;
      }
    }
    work[cell] = 0;
    return false;
  }

  if (countSolutions(grid, limit: 1) == 0) return null;
  return fill(0) ? work : null;
}

List<int> _randomSolution(Random rng) {
  final grid = List.filled(81, 0);
  bool fill(int cell) {
    if (cell == 81) return true;
    for (final d in List.generate(9, (i) => i + 1)..shuffle(rng)) {
      if (_canPlace(grid, cell, d)) {
        grid[cell] = d;
        if (fill(cell + 1)) return true;
      }
    }
    grid[cell] = 0;
    return false;
  }

  fill(0);
  return grid;
}

/// The state of one round: the player's entries on top of a puzzle.
class SudokuEngine {
  SudokuEngine(this.puzzle) : _values = List.of(puzzle.givens);
  final SudokuPuzzle puzzle;
  final List<int> _values;
  final List<Set<int>> _notes = List.generate(81, (_) => <int>{});

  List<int> get values => List.unmodifiable(_values);
  bool isGiven(int cell) => puzzle.givens[cell] != 0;
  bool get hasProgress => List.generate(
    81,
    (i) => i,
  ).any((i) => (!isGiven(i) && _values[i] != 0) || _notes[i].isNotEmpty);

  /// The pencil marks the player has jotted in [cell].
  Set<int> notesAt(int cell) => Set.unmodifiable(_notes[cell]);

  /// Places [digit] (1–9), or clears the cell when [digit] is 0. Returns false
  /// for clues, finished puzzles, and invalid input. Placing a digit wipes the
  /// cell's notes and crosses that digit off the notes of its peers.
  bool setValue(int cell, int digit) {
    if (cell < 0 || cell >= 81 || digit < 0 || digit > 9) return false;
    if (isGiven(cell) || isSolved || _values[cell] == digit) return false;
    _values[cell] = digit;
    if (digit != 0) {
      _notes[cell].clear();
      for (final p in peers[cell]) {
        _notes[p].remove(digit);
      }
    }
    return true;
  }

  /// Adds or removes [digit] as a pencil mark in an empty, non-clue [cell].
  bool toggleNote(int cell, int digit) {
    if (cell < 0 || cell >= 81 || digit < 1 || digit > 9) return false;
    if (isGiven(cell) || isSolved || _values[cell] != 0) return false;
    if (!_notes[cell].remove(digit)) _notes[cell].add(digit);
    return true;
  }

  /// Removes every pencil mark from [cell]. Returns false if there were none.
  bool clearNotes(int cell) {
    if (cell < 0 || cell >= 81 || _notes[cell].isEmpty || isSolved) {
      return false;
    }
    _notes[cell].clear();
    return true;
  }

  /// Cells whose number repeats in their row, column, or box.
  Set<int> get conflicts => {
    for (var cell = 0; cell < 81; cell++)
      if (_values[cell] != 0 &&
          peers[cell].any((p) => _values[p] == _values[cell]))
        cell,
  };

  /// How many times [digit] appears on the board.
  int countOf(int digit) => _values.where((v) => v == digit).length;

  bool get isSolved {
    for (var cell = 0; cell < 81; cell++) {
      if (_values[cell] != puzzle.solution[cell]) return false;
    }
    return true;
  }
}
