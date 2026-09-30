class TicTacToeEngine {
  final List<String> _board = List.filled(9, '');
  List<String> get board => List.unmodifiable(_board);
  String turn = 'X';
  String? get winner => winnerOf(_board);
  bool get isDraw => winner == null && !_board.contains('');
  bool get isFinished => winner != null || isDraw;

  bool play(int cell) {
    if (cell < 0 || cell >= 9 || isFinished || _board[cell].isNotEmpty) {
      return false;
    }
    _board[cell] = turn;
    if (!isFinished) turn = turn == 'X' ? 'O' : 'X';
    return true;
  }

  static String? winnerOf(List<String> board) {
    for (final line in const [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ]) {
      final mark = board[line[0]];
      if (mark.isNotEmpty && mark == board[line[1]] && mark == board[line[2]]) {
        return mark;
      }
    }
    return null;
  }
}
