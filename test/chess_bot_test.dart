import 'package:flutter_test/flutter_test.dart';
import 'package:csc_4330_app_4/games/chess/chess_bot.dart';
import 'package:csc_4330_app_4/games/chess/chess_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Bot chooses a legal move without mutating the caller position',
    () async {
      final game = ChessEngine.initial();
      final original = game.toFen();
      final move = await const ChessBot().chooseMove(game);
      expect(move, isNotNull);
      expect(game.toFen(), original);
      expect(
        game.makeMove(move!.from, move.to, promotion: move.promotion),
        isTrue,
      );
      expect(game.turn, 'b');
    },
  );

  test('Bot takes an undefended queen', () async {
    final game = ChessEngine.fromFen('7k/8/8/8/8/8/q7/R6K w - - 0 1');
    final move = await const ChessBot(depth: 1).chooseMove(game);
    expect(move, isNotNull);
    expect(move!.from, 0);
    expect(move.to, 8);
  });

  test('Bot finds a mate in one', () async {
    final game = ChessEngine.fromFen('7k/8/5KQ1/8/8/8/8/8 w - - 0 1');
    final move = await const ChessBot().chooseMove(game);
    expect(move, isNotNull);
    game.applyMove(move!);
    expect(game.isCheckmate, isTrue);
    expect(game.winner, 'w');
  });

  for (final fen in [
    '7k/6Q1/6K1/8/8/8/8/8 b - - 0 1',
    '7k/5Q2/6K1/8/8/8/8/8 b - - 0 1',
  ]) {
    test('Bot returns no move in a terminal position: $fen', () async {
      expect(
        await const ChessBot().chooseMove(ChessEngine.fromFen(fen)),
        isNull,
      );
    });
  }
}
