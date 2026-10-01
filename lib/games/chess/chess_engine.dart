const _knightDeltas = [
  (1, 2),
  (2, 1),
  (2, -1),
  (1, -2),
  (-1, -2),
  (-2, -1),
  (-2, 1),
  (-1, 2),
];
const _kingDeltas = [
  (1, 0),
  (1, 1),
  (0, 1),
  (-1, 1),
  (-1, 0),
  (-1, -1),
  (0, -1),
  (1, -1),
];
const _bishopDirs = [(1, 1), (1, -1), (-1, 1), (-1, -1)];
const _rookDirs = [(1, 0), (-1, 0), (0, 1), (0, -1)];
const _queenDirs = [..._bishopDirs, ..._rookDirs];

const kChessInitialFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// A single chess move. [promotion] and the castle/en-passant flags are
/// always derived from legal move generation, never guessed by callers.
class ChessMove {
  const ChessMove(
    this.from,
    this.to, {
    this.promotion,
    this.isCastle = false,
    this.isEnPassant = false,
    this.rookFrom,
    this.rookTo,
  });
  final int from;
  final int to;
  final String? promotion;
  final bool isCastle;
  final bool isEnPassant;
  final int? rookFrom;
  final int? rookTo;

  @override
  bool operator ==(Object other) =>
      other is ChessMove &&
      other.from == from &&
      other.to == to &&
      other.promotion == promotion;
  @override
  int get hashCode => Object.hash(from, to, promotion);
}

/// Square indices run 0 (a1) to 63 (h8), file = index % 8, rank = index ~/ 8.
class ChessEngine {
  ChessEngine._({
    required List<String> board,
    required this.turn,
    required this.castling,
    required this.enPassant,
    required this.halfmoveClock,
    required this.fullmoveNumber,
  }) : _board = board; // ignore: prefer_initializing_formals (field is private; param name mirrors it)

  factory ChessEngine.initial() => ChessEngine.fromFen(kChessInitialFen);

  factory ChessEngine.fromFen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    final placement = parts[0];
    final active = parts.length > 1 ? parts[1] : 'w';
    final castle = parts.length > 2 ? parts[2] : '-';
    final ep = parts.length > 3 ? parts[3] : '-';
    final half = parts.length > 4 ? int.tryParse(parts[4]) ?? 0 : 0;
    final full = parts.length > 5 ? int.tryParse(parts[5]) ?? 1 : 1;
    final board = List<String>.filled(64, '');
    final ranks = placement.split('/');
    for (var i = 0; i < 8 && i < ranks.length; i++) {
      final rankIndex = 7 - i;
      var file = 0;
      for (final char in ranks[i].split('')) {
        final digit = int.tryParse(char);
        if (digit != null) {
          file += digit;
        } else {
          board[rankIndex * 8 + file] = char;
          file++;
        }
      }
    }
    return ChessEngine._(
      board: board,
      turn: active,
      castling: castle == '-' ? '' : castle,
      enPassant: ep == '-' ? null : _squareIndex(ep),
      halfmoveClock: half,
      fullmoveNumber: full,
    );
  }

  final List<String> _board;
  String turn;
  String castling;
  int? enPassant;
  int halfmoveClock;
  int fullmoveNumber;

  List<String> get board => List.unmodifiable(_board);

  bool get isCheck => _attacked(
    _board.indexOf(turn == 'w' ? 'K' : 'k'),
    turn == 'w' ? 'b' : 'w',
  );
  bool get isCheckmate => isCheck && allLegalMoves().isEmpty;
  bool get isStalemate => !isCheck && allLegalMoves().isEmpty;
  bool get isDraw =>
      isStalemate || _insufficientMaterial() || halfmoveClock >= 100;
  bool get isFinished => isCheckmate || isDraw;

  /// Color ('w'/'b') of the side that delivered checkmate, else null.
  String? get winner => isCheckmate ? (turn == 'w' ? 'b' : 'w') : null;

  ChessEngine clone() => ChessEngine._(
    board: List<String>.from(_board),
    turn: turn,
    castling: castling,
    enPassant: enPassant,
    halfmoveClock: halfmoveClock,
    fullmoveNumber: fullmoveNumber,
  );

  List<ChessMove> movesFrom(int square) =>
      allLegalMoves().where((move) => move.from == square).toList();

  List<ChessMove> allLegalMoves() {
    final moves = <ChessMove>[];
    for (var square = 0; square < 64; square++) {
      final piece = _board[square];
      if (piece.isEmpty || _colorOf(piece) != turn) continue;
      moves.addAll(_pseudoMoves(square, piece));
    }
    return moves.where(_leavesKingSafe).toList();
  }

  /// Applies an already-legal move; moving an opponent's piece or an
  /// otherwise illegal move will corrupt engine state, so always source
  /// moves from [allLegalMoves] or [movesFrom].
  void applyMove(ChessMove move) {
    final piece = _board[move.from];
    final color = _colorOf(piece)!;
    final captured = _board[move.to];
    _board[move.from] = '';
    _board[move.to] = move.promotion != null
        ? (color == 'w'
              ? move.promotion!.toUpperCase()
              : move.promotion!.toLowerCase())
        : piece;
    if (move.isEnPassant) {
      final capturedSquare = move.to + (color == 'w' ? -8 : 8);
      _board[capturedSquare] = '';
    }
    if (move.isCastle) {
      _board[move.rookTo!] = _board[move.rookFrom!];
      _board[move.rookFrom!] = '';
    }
    _updateCastlingRights(piece, move.from, move.to);
    enPassant =
        (piece.toUpperCase() == 'P' && (move.to - move.from).abs() == 16)
        ? (move.from + move.to) ~/ 2
        : null;
    halfmoveClock = (piece.toUpperCase() == 'P' || captured.isNotEmpty)
        ? 0
        : halfmoveClock + 1;
    if (turn == 'b') fullmoveNumber++;
    turn = turn == 'w' ? 'b' : 'w';
  }

  bool makeMove(int from, int to, {String? promotion}) {
    final candidates = allLegalMoves()
        .where((move) => move.from == from && move.to == to)
        .toList();
    if (candidates.isEmpty) return false;
    final wanted = promotion?.toUpperCase() ?? 'Q';
    final move = candidates.firstWhere(
      (m) => m.promotion == null || m.promotion == wanted,
      orElse: () => candidates.first,
    );
    applyMove(move);
    return true;
  }

  String toFen() {
    final ranks = <String>[];
    for (var i = 7; i >= 0; i--) {
      var empty = 0;
      final buffer = StringBuffer();
      for (var file = 0; file < 8; file++) {
        final piece = _board[i * 8 + file];
        if (piece.isEmpty) {
          empty++;
        } else {
          if (empty > 0) {
            buffer.write(empty);
            empty = 0;
          }
          buffer.write(piece);
        }
      }
      if (empty > 0) buffer.write(empty);
      ranks.add(buffer.toString());
    }
    final castle = castling.isEmpty ? '-' : castling;
    final ep = enPassant == null ? '-' : _squareName(enPassant!);
    return '${ranks.join('/')} $turn $castle $ep $halfmoveClock $fullmoveNumber';
  }

  static String encodeMove(ChessMove move) =>
      '${_squareName(move.from)}${_squareName(move.to)}${move.promotion ?? ''}';

  static ChessMove decodeMove(String code) => ChessMove(
    _squareIndex(code.substring(0, 2)),
    _squareIndex(code.substring(2, 4)),
    promotion: code.length > 4 ? code.substring(4) : null,
  );

  static String _squareName(int square) =>
      '${String.fromCharCode(97 + square % 8)}${square ~/ 8 + 1}';
  static int _squareIndex(String name) =>
      (name.codeUnitAt(0) - 97) + (int.parse(name.substring(1)) - 1) * 8;

  static String? _colorOf(String piece) =>
      piece.isEmpty ? null : (piece == piece.toUpperCase() ? 'w' : 'b');

  /// Public accessor for UI code that needs to know whose piece occupies a square.
  static String? colorOf(String piece) => _colorOf(piece);
  static bool _inBounds(int file, int rank) =>
      file >= 0 && file < 8 && rank >= 0 && rank < 8;

  List<ChessMove> _pseudoMoves(int square, String piece) {
    final color = _colorOf(piece)!;
    switch (piece.toUpperCase()) {
      case 'P':
        return _pawnMoves(square, color);
      case 'N':
        return _stepMoves(square, color, _knightDeltas);
      case 'B':
        return _slideMoves(square, color, _bishopDirs);
      case 'R':
        return _slideMoves(square, color, _rookDirs);
      case 'Q':
        return _slideMoves(square, color, _queenDirs);
      case 'K':
        return [
          ..._stepMoves(square, color, _kingDeltas),
          ..._castleMoves(square, color),
        ];
      default:
        return const [];
    }
  }

  List<ChessMove> _pawnMoves(int square, String color) {
    final moves = <ChessMove>[];
    final file = square % 8, rank = square ~/ 8;
    final dir = color == 'w' ? 1 : -1;
    final startRank = color == 'w' ? 1 : 6;
    final lastRank = color == 'w' ? 7 : 0;
    final oneRank = rank + dir;
    if (_inBounds(file, oneRank)) {
      final oneSquare = oneRank * 8 + file;
      if (_board[oneSquare].isEmpty) {
        _addPawnMove(moves, square, oneSquare, oneRank == lastRank);
        final twoRank = rank + 2 * dir;
        if (rank == startRank && _inBounds(file, twoRank)) {
          final twoSquare = twoRank * 8 + file;
          if (_board[twoSquare].isEmpty) {
            moves.add(ChessMove(square, twoSquare));
          }
        }
      }
      for (final df in [-1, 1]) {
        final captureFile = file + df;
        if (!_inBounds(captureFile, oneRank)) continue;
        final captureSquare = oneRank * 8 + captureFile;
        final target = _board[captureSquare];
        if (target.isNotEmpty && _colorOf(target) != color) {
          _addPawnMove(moves, square, captureSquare, oneRank == lastRank);
        } else if (captureSquare == enPassant) {
          moves.add(ChessMove(square, captureSquare, isEnPassant: true));
        }
      }
    }
    return moves;
  }

  void _addPawnMove(List<ChessMove> moves, int from, int to, bool promotes) {
    if (promotes) {
      for (final p in const ['Q', 'R', 'B', 'N']) {
        moves.add(ChessMove(from, to, promotion: p));
      }
    } else {
      moves.add(ChessMove(from, to));
    }
  }

  List<ChessMove> _stepMoves(
    int square,
    String color,
    List<(int, int)> deltas,
  ) {
    final moves = <ChessMove>[];
    final file = square % 8, rank = square ~/ 8;
    for (final d in deltas) {
      final f = file + d.$1, r = rank + d.$2;
      if (!_inBounds(f, r)) continue;
      final target = _board[r * 8 + f];
      if (target.isEmpty || _colorOf(target) != color) {
        moves.add(ChessMove(square, r * 8 + f));
      }
    }
    return moves;
  }

  List<ChessMove> _slideMoves(int square, String color, List<(int, int)> dirs) {
    final moves = <ChessMove>[];
    final file = square % 8, rank = square ~/ 8;
    for (final d in dirs) {
      var f = file + d.$1, r = rank + d.$2;
      while (_inBounds(f, r)) {
        final target = _board[r * 8 + f];
        if (target.isEmpty) {
          moves.add(ChessMove(square, r * 8 + f));
        } else {
          if (_colorOf(target) != color) {
            moves.add(ChessMove(square, r * 8 + f));
          }
          break;
        }
        f += d.$1;
        r += d.$2;
      }
    }
    return moves;
  }

  List<ChessMove> _castleMoves(int square, String color) {
    final moves = <ChessMove>[];
    final opponent = color == 'w' ? 'b' : 'w';
    if (_attacked(square, opponent)) return moves;
    if (color == 'w' && square == 4) {
      if (castling.contains('K') &&
          _board[5].isEmpty &&
          _board[6].isEmpty &&
          _board[7] == 'R' &&
          !_attacked(5, opponent) &&
          !_attacked(6, opponent)) {
        moves.add(
          const ChessMove(4, 6, isCastle: true, rookFrom: 7, rookTo: 5),
        );
      }
      if (castling.contains('Q') &&
          _board[3].isEmpty &&
          _board[2].isEmpty &&
          _board[1].isEmpty &&
          _board[0] == 'R' &&
          !_attacked(3, opponent) &&
          !_attacked(2, opponent)) {
        moves.add(
          const ChessMove(4, 2, isCastle: true, rookFrom: 0, rookTo: 3),
        );
      }
    } else if (color == 'b' && square == 60) {
      if (castling.contains('k') &&
          _board[61].isEmpty &&
          _board[62].isEmpty &&
          _board[63] == 'r' &&
          !_attacked(61, opponent) &&
          !_attacked(62, opponent)) {
        moves.add(
          const ChessMove(60, 62, isCastle: true, rookFrom: 63, rookTo: 61),
        );
      }
      if (castling.contains('q') &&
          _board[59].isEmpty &&
          _board[58].isEmpty &&
          _board[57].isEmpty &&
          _board[56] == 'r' &&
          !_attacked(59, opponent) &&
          !_attacked(58, opponent)) {
        moves.add(
          const ChessMove(60, 58, isCastle: true, rookFrom: 56, rookTo: 59),
        );
      }
    }
    return moves;
  }

  bool _attacked(int square, String byColor) {
    final file = square % 8, rank = square ~/ 8;
    final pawnRank = rank + (byColor == 'w' ? -1 : 1);
    for (final df in [-1, 1]) {
      final f = file + df;
      if (_inBounds(f, pawnRank) &&
          _board[pawnRank * 8 + f] == (byColor == 'w' ? 'P' : 'p')) {
        return true;
      }
    }
    for (final d in _knightDeltas) {
      final f = file + d.$1, r = rank + d.$2;
      if (_inBounds(f, r) &&
          _board[r * 8 + f] == (byColor == 'w' ? 'N' : 'n')) {
        return true;
      }
    }
    for (final d in _kingDeltas) {
      final f = file + d.$1, r = rank + d.$2;
      if (_inBounds(f, r) &&
          _board[r * 8 + f] == (byColor == 'w' ? 'K' : 'k')) {
        return true;
      }
    }
    for (final d in _bishopDirs) {
      var f = file + d.$1, r = rank + d.$2;
      while (_inBounds(f, r)) {
        final p = _board[r * 8 + f];
        if (p.isNotEmpty) {
          if (_colorOf(p) == byColor &&
              (p.toUpperCase() == 'B' || p.toUpperCase() == 'Q')) {
            return true;
          }
          break;
        }
        f += d.$1;
        r += d.$2;
      }
    }
    for (final d in _rookDirs) {
      var f = file + d.$1, r = rank + d.$2;
      while (_inBounds(f, r)) {
        final p = _board[r * 8 + f];
        if (p.isNotEmpty) {
          if (_colorOf(p) == byColor &&
              (p.toUpperCase() == 'R' || p.toUpperCase() == 'Q')) {
            return true;
          }
          break;
        }
        f += d.$1;
        r += d.$2;
      }
    }
    return false;
  }

  bool _leavesKingSafe(ChessMove move) {
    final mover = turn;
    final test = clone()..applyMove(move);
    final kingSquare = test._board.indexOf(mover == 'w' ? 'K' : 'k');
    return !test._attacked(kingSquare, mover == 'w' ? 'b' : 'w');
  }

  void _updateCastlingRights(String piece, int from, int to) {
    if (piece == 'K') {
      castling = castling.replaceAll('K', '').replaceAll('Q', '');
    }
    if (piece == 'k') {
      castling = castling.replaceAll('k', '').replaceAll('q', '');
    }
    if (from == 0 || to == 0) castling = castling.replaceAll('Q', '');
    if (from == 7 || to == 7) castling = castling.replaceAll('K', '');
    if (from == 56 || to == 56) castling = castling.replaceAll('q', '');
    if (from == 63 || to == 63) castling = castling.replaceAll('k', '');
  }

  bool _insufficientMaterial() {
    final pieces = _board
        .where((p) => p.isNotEmpty && p.toUpperCase() != 'K')
        .toList();
    if (pieces.isEmpty) return true;
    if (pieces.length == 1 &&
        (pieces.first.toUpperCase() == 'B' ||
            pieces.first.toUpperCase() == 'N')) {
      return true;
    }
    return false;
  }
}
