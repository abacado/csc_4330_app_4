import 'package:csc_4330_app_4/core/game_result.dart';
import 'package:csc_4330_app_4/services/cloud_service.dart';

class FakeCloud implements CloudService {
  bool fail = false;
  final saved = <String, GameResult>{};
  final moves = <int>[];
  String? joinedCode;
  @override
  String get userId => 'host';
  void check() {
    if (fail) throw StateError('offline');
  }

  @override
  Future<void> connect() async {
    check();
  }

  @override
  Future<void> saveResults(List<GameResult> results) async {
    check();
    for (final result in results) {
      saved[result.id] = result;
    }
  }

  @override
  Future<List<GameResult>> loadResults() async {
    check();
    return saved.values.toList();
  }

  OnlineRoom room = OnlineRoom.fromJson({
    'code': 'ABC123',
    'host_id': 'host',
    'guest_id': null,
    'board': List.filled(9, ''),
    'turn': 'X',
    'status': 'waiting',
    'winner': null,
  });
  @override
  Future<OnlineRoom> createRoom() async {
    check();
    return room;
  }

  @override
  Future<OnlineRoom> joinRoom(String code) async {
    check();
    joinedCode = code;
    return room;
  }

  @override
  Future<OnlineRoom> getRoom(String code) async {
    check();
    return room;
  }

  @override
  Future<OnlineRoom> playMove(String code, int cell) async {
    check();
    moves.add(cell);
    return room;
  }

  ChessRoom chessRoom = ChessRoom.fromJson({
    'code': 'ABC123',
    'host_id': 'host',
    'guest_id': null,
    'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    'status': 'waiting',
    'winner': null,
  });
  String? joinedChessCode;
  final chessMoves = <String>[];
  @override
  Future<ChessRoom> createChessRoom() async {
    check();
    return chessRoom;
  }

  @override
  Future<ChessRoom> joinChessRoom(String code) async {
    check();
    joinedChessCode = code;
    return chessRoom;
  }

  @override
  Future<ChessRoom> getChessRoom(String code) async {
    check();
    return chessRoom;
  }

  @override
  Future<ChessRoom> playChessMove(
    String code,
    String fen, {
    required String status,
    String? winner,
  }) async {
    check();
    chessMoves.add(fen);
    return chessRoom;
  }
}
