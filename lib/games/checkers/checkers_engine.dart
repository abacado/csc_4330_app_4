/// Pure rules for Checkers, American/English variant:
/// - 8×8 board, pieces on dark squares only; Black moves first.
/// - Men move one square diagonally forward; kings move both ways.
/// - Captures are mandatory. If a piece can keep jumping after a capture,
///   it must continue with that same piece before the turn ends.
/// - A man reaching the far row is crowned, which ends the move.
/// - A player with no pieces or no legal moves loses.
///
/// Squares are indexed 0–63, row by row from Black's side (row 0).
enum Side {
  black('Black'),
  red('Red');

  const Side(this.label);
  final String label;
  Side get opponent => this == black ? red : black;
}

class Piece {
  const Piece(this.side, {this.king = false});
  final Side side;
  final bool king;
}

class CheckersMove {
  const CheckersMove(this.from, this.to, {this.captured});
  final int from, to;

  /// The square of the jumped piece, or null for a simple move.
  final int? captured;
  bool get isJump => captured != null;
}

int rowOf(int square) => square ~/ 8;
int colOf(int square) => square % 8;
bool isDarkSquare(int square) => (rowOf(square) + colOf(square)).isOdd;
bool _onBoard(int row, int col) => row >= 0 && row < 8 && col >= 0 && col < 8;

class CheckersEngine {
  /// The standard starting position: 12 pieces each.
  CheckersEngine() : _board = List.filled(64, null), _turn = Side.black {
    for (var square = 0; square < 64; square++) {
      if (!isDarkSquare(square)) continue;
      if (rowOf(square) < 3) _board[square] = const Piece(Side.black);
      if (rowOf(square) > 4) _board[square] = const Piece(Side.red);
    }
  }

  /// A custom position, e.g. in tests. Pieces must be on dark squares.
  CheckersEngine.fromPieces(Map<int, Piece> pieces, {this._turn = Side.black})
    : _board = List.filled(64, null) {
    pieces.forEach((square, piece) {
      if (square < 0 || square >= 64 || !isDarkSquare(square)) {
        throw ArgumentError.value(square, 'square', 'Not a dark square.');
      }
      _board[square] = piece;
    });
  }

  final List<Piece?> _board;

  /// Restore a server-authoritative board, including a pending multiple jump.
  factory CheckersEngine.fromOnline(List<int> board, String turn, int? jumper) {
    if (board.length != 64 ||
        board.any((p) => ![-2, -1, 0, 1, 2].contains(p))) {
      throw ArgumentError('Invalid checkers board');
    }
    if (turn != 'black' && turn != 'red') throw ArgumentError('Invalid turn');
    final game = CheckersEngine.fromPieces({
      for (var i = 0; i < 64; i++)
        if (board[i] != 0)
          i: Piece(
            board[i] > 0 ? Side.black : Side.red,
            king: board[i].abs() == 2,
          ),
    }, turn: turn == 'black' ? Side.black : Side.red);
    game._jumper = jumper;
    return game;
  }
  Side _turn;
  int? _jumper;
  int _moveCount = 0;

  Side get turn => _turn;
  Piece? pieceAt(int square) => _board[square];
  int pieceCount(Side side) => _board.where((p) => p?.side == side).length;
  bool get hasProgress => _moveCount > 0;

  /// The piece that must keep jumping this turn, if any.
  int? get mustContinueFrom => _jumper;

  /// Every legal move for the side to play. Jumps are mandatory, so when
  /// any jump exists only jumps are returned.
  List<CheckersMove> get legalMoves {
    if (_jumper != null) return _movesFrom(_jumper!, jumpsOnly: true);
    final all = [
      for (var square = 0; square < 64; square++)
        if (_board[square]?.side == _turn)
          ..._movesFrom(square, jumpsOnly: false),
    ];
    final jumps = all.where((m) => m.isJump).toList();
    return jumps.isNotEmpty ? jumps : all;
  }

  List<CheckersMove> movesFrom(int square) =>
      legalMoves.where((m) => m.from == square).toList();

  /// The winner once the side to play has no legal move, otherwise null.
  Side? get winner => legalMoves.isEmpty ? _turn.opponent : null;
  bool get isOver => winner != null;

  /// Plays a move. Returns false if it is not legal.
  bool move(int from, int to) {
    final chosen = legalMoves
        .where((m) => m.from == from && m.to == to)
        .firstOrNull;
    if (chosen == null) return false;

    final piece = _board[from]!;
    _board[from] = null;
    if (chosen.captured != null) _board[chosen.captured!] = null;
    final farRow = piece.side == Side.black ? 7 : 0;
    final crowned = !piece.king && rowOf(to) == farRow;
    _board[to] = crowned ? Piece(piece.side, king: true) : piece;
    _moveCount++;

    if (chosen.isJump &&
        !crowned &&
        _movesFrom(to, jumpsOnly: true).isNotEmpty) {
      _jumper = to;
    } else {
      _jumper = null;
      _turn = _turn.opponent;
    }
    return true;
  }

  List<CheckersMove> _movesFrom(int from, {required bool jumpsOnly}) {
    final piece = _board[from];
    if (piece == null) return const [];
    final directions = [
      if (piece.king || piece.side == Side.red) ...[(-1, -1), (-1, 1)],
      if (piece.king || piece.side == Side.black) ...[(1, -1), (1, 1)],
    ];
    final moves = <CheckersMove>[];
    for (final (dr, dc) in directions) {
      final row = rowOf(from) + dr, col = colOf(from) + dc;
      if (!_onBoard(row, col)) continue;
      final next = row * 8 + col;
      final target = _board[next];
      if (target == null) {
        if (!jumpsOnly) moves.add(CheckersMove(from, next));
        continue;
      }
      if (target.side == piece.side) continue;
      final landRow = row + dr, landCol = col + dc;
      if (_onBoard(landRow, landCol) && _board[landRow * 8 + landCol] == null) {
        moves.add(CheckersMove(from, landRow * 8 + landCol, captured: next));
      }
    }
    return moves;
  }
}
