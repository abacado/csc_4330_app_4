import 'dart:math';

enum SlideDirection { left, right, up, down }

/// Pure rules for 2048: a 4x4 grid of tiles that slide and merge, a new tile
/// after every move that changes the board, and a running score. Cells are
/// indexed row by row, 0 to 15; an empty cell holds 0. Reaching [target]
/// counts as a win, but play may continue until no move is left.
class Game2048Engine {
  /// Starts a fresh board with two random tiles.
  Game2048Engine({Random? random})
    : _random = random ?? Random(),
      _tiles = List.filled(size * size, 0) {
    _spawnTile();
    _spawnTile();
  }

  /// Uses a fixed starting layout, e.g. in tests. [tiles] must hold exactly
  /// 16 values, each 0 or a power of two from 2 upward.
  Game2048Engine.fromTiles(List<int> tiles, {Random? random, int score = 0})
    : _random = random ?? Random(),
      _tiles = List.of(tiles),
      _score = score {
    if (tiles.length != size * size) {
      throw ArgumentError.value(tiles, 'tiles', 'Need exactly 16 cells.');
    }
    if (tiles.any((t) => t != 0 && (t < 2 || t & (t - 1) != 0))) {
      throw ArgumentError.value(tiles, 'tiles', 'Tiles must be powers of two.');
    }
  }

  static const size = 4;
  static const target = 2048;

  final Random _random;
  final List<int> _tiles;
  int _score = 0;
  int _moves = 0;

  List<int> get tiles => List.unmodifiable(_tiles);
  int tileAt(int row, int col) => _tiles[row * size + col];
  int get score => _score;
  int get moves => _moves;
  int get highestTile => _tiles.reduce(max);
  bool get isWon => highestTile >= target;
  bool get hasProgress => _moves > 0;

  /// True when no slide in any direction would change the board.
  bool get isGameOver {
    if (_tiles.contains(0)) return false;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final tile = tileAt(r, c);
        if (c + 1 < size && tile == tileAt(r, c + 1)) return false;
        if (r + 1 < size && tile == tileAt(r + 1, c)) return false;
      }
    }
    return true;
  }

  /// Slides every tile toward [direction], merging equal neighbors once per
  /// move, then spawns a new tile. Returns false and leaves the board (and
  /// score) untouched when the slide would change nothing.
  bool move(SlideDirection direction) {
    var changed = false;
    for (final line in _linesToward(direction)) {
      final before = [for (final i in line) _tiles[i]];
      final (after, gained) = slideLine(before);
      for (var k = 0; k < size; k++) {
        if (after[k] != before[k]) changed = true;
        _tiles[line[k]] = after[k];
      }
      _score += gained;
    }
    if (!changed) return false;
    _moves++;
    _spawnTile();
    return true;
  }

  /// Slides one line toward index 0. Each tile merges at most once, and the
  /// pair nearest the leading edge merges first, so [2, 2, 2, 0] becomes
  /// [4, 2, 0, 0]. Returns the new line and the points earned by merges.
  static (List<int>, int) slideLine(List<int> line) {
    final packed = line.where((t) => t != 0).toList();
    final result = <int>[];
    var gained = 0;
    for (var i = 0; i < packed.length; i++) {
      if (i + 1 < packed.length && packed[i] == packed[i + 1]) {
        final merged = packed[i] * 2;
        result.add(merged);
        gained += merged;
        i++;
      } else {
        result.add(packed[i]);
      }
    }
    while (result.length < line.length) {
      result.add(0);
    }
    return (result, gained);
  }

  /// Each row or column as cell indices, ordered from the edge the tiles
  /// slide toward.
  List<List<int>> _linesToward(SlideDirection direction) => [
    for (var a = 0; a < size; a++)
      [
        for (var b = 0; b < size; b++)
          switch (direction) {
            SlideDirection.left => a * size + b,
            SlideDirection.right => a * size + (size - 1 - b),
            SlideDirection.up => b * size + a,
            SlideDirection.down => (size - 1 - b) * size + a,
          },
      ],
  ];

  /// Places a 2 (90%) or a 4 (10%) on a random empty cell, if any.
  void _spawnTile() {
    final empty = [
      for (var i = 0; i < _tiles.length; i++)
        if (_tiles[i] == 0) i,
    ];
    if (empty.isEmpty) return;
    final cell = empty[_random.nextInt(empty.length)];
    _tiles[cell] = _random.nextInt(10) == 0 ? 4 : 2;
  }
}
