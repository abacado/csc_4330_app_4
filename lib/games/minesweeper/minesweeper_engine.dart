import 'dart:math';

enum MinesweeperDifficulty {
  easy('Easy', 8, 8, 10),
  medium('Medium', 12, 12, 24),
  hard('Hard', 16, 16, 40);

  const MinesweeperDifficulty(this.label, this.rows, this.cols, this.mines);
  final String label;
  final int rows, cols, mines;
}

/// A single round of Minesweeper. Cells are indexed row by row, 0 to
/// rows*cols - 1. Mines are placed on the first reveal so that the opening
/// move is never a mine.
class MinesweeperEngine {
  MinesweeperEngine(this.difficulty, {Random? random})
    : rows = difficulty.rows,
      cols = difficulty.cols,
      mineCount = difficulty.mines,
      _random = random ?? Random(),
      _mines = List.filled(difficulty.rows * difficulty.cols, false),
      _revealed = List.filled(difficulty.rows * difficulty.cols, false),
      _flagged = List.filled(difficulty.rows * difficulty.cols, false);

  /// Builds an engine with mines already placed at fixed [mines] cells,
  /// bypassing random/safe-first-click placement. Intended for tests.
  factory MinesweeperEngine.fixed({
    required MinesweeperDifficulty difficulty,
    required Set<int> mines,
  }) {
    final engine = MinesweeperEngine(difficulty);
    for (final cell in mines) {
      engine._mines[cell] = true;
    }
    engine._minesPlaced = true;
    return engine;
  }

  final MinesweeperDifficulty difficulty;
  final int rows, cols, mineCount;
  final Random _random;
  final List<bool> _mines, _revealed, _flagged;
  bool _minesPlaced = false;
  bool _hitMine = false;

  int get cellCount => rows * cols;
  List<bool> get revealed => List.unmodifiable(_revealed);
  List<bool> get flagged => List.unmodifiable(_flagged);
  bool isMine(int cell) => _mines[cell];
  bool isRevealed(int cell) => _revealed[cell];
  bool isFlagged(int cell) => _flagged[cell];
  bool get isLoss => _hitMine;
  bool get isWin =>
      !_hitMine &&
      _minesPlaced &&
      List.generate(
        cellCount,
        (i) => i,
      ).every((i) => _mines[i] || _revealed[i]);
  bool get isFinished => isWin || isLoss;
  int get flagsPlaced => _flagged.where((f) => f).length;
  int get minesRemaining => mineCount - flagsPlaced;
  bool get hasProgress => _revealed.any((r) => r) || _flagged.any((f) => f);

  int rowOf(int cell) => cell ~/ cols;
  int colOf(int cell) => cell % cols;

  List<int> _neighborsOf(int cell) {
    final r = rowOf(cell), c = colOf(cell);
    return [
      for (var dr = -1; dr <= 1; dr++)
        for (var dc = -1; dc <= 1; dc++)
          if ((dr != 0 || dc != 0) &&
              r + dr >= 0 &&
              r + dr < rows &&
              c + dc >= 0 &&
              c + dc < cols)
            (r + dr) * cols + (c + dc),
    ];
  }

  int adjacentMines(int cell) =>
      _neighborsOf(cell).where((n) => _mines[n]).length;

  void _placeMines(int safeCell) {
    final excluded = {safeCell, ..._neighborsOf(safeCell)};
    final candidates = [
      for (var i = 0; i < cellCount; i++)
        if (!excluded.contains(i)) i,
    ]..shuffle(_random);
    for (final cell in candidates.take(mineCount)) {
      _mines[cell] = true;
    }
    _minesPlaced = true;
  }

  /// Reveals [cell], flood-filling connected zero-mine-count cells. Returns
  /// false if the cell is already revealed, flagged, or the game is over.
  bool reveal(int cell) {
    if (isFinished || _flagged[cell] || _revealed[cell]) return false;
    if (!_minesPlaced) _placeMines(cell);
    if (_mines[cell]) {
      _revealed[cell] = true;
      _hitMine = true;
      return true;
    }
    final queue = [cell];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (_revealed[current] || _flagged[current]) continue;
      _revealed[current] = true;
      if (adjacentMines(current) == 0) queue.addAll(_neighborsOf(current));
    }
    return true;
  }

  /// Flags or unflags an unrevealed [cell]. Returns false when the game is
  /// over or the cell is already revealed.
  bool toggleFlag(int cell) {
    if (isFinished || _revealed[cell]) return false;
    _flagged[cell] = !_flagged[cell];
    return true;
  }
}
