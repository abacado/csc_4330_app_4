import '../core/game_result.dart';

class OnlineRoom {
  OnlineRoom.fromJson(Map<String, dynamic> json)
    : code = json['code'] as String,
      hostId = json['host_id'] as String,
      guestId = json['guest_id'] as String?,
      board = List<String>.from(json['board'] as List),
      turn = json['turn'] as String,
      status = json['status'] as String,
      winner = json['winner'] as String?;
  final String code, hostId, turn, status;
  final String? guestId, winner;
  final List<String> board;
  String? markFor(String userId) => userId == hostId
      ? 'X'
      : userId == guestId
      ? 'O'
      : null;
}

class ChessRoom {
  ChessRoom.fromJson(Map<String, dynamic> json)
    : code = json['code'] as String,
      hostId = json['host_id'] as String,
      guestId = json['guest_id'] as String?,
      fen = json['fen'] as String,
      status = json['status'] as String,
      winner = json['winner'] as String?;
  final String code, hostId, fen, status;
  final String? guestId, winner;

  /// 'white' or 'black', derived from the FEN's active-color field.
  String get turn => fen.split(' ')[1] == 'w' ? 'white' : 'black';
  String? colorFor(String userId) => userId == hostId
      ? 'white'
      : userId == guestId
      ? 'black'
      : null;
}

abstract class CloudService {
  String get userId;
  Future<void> connect();
  Future<void> saveResults(List<GameResult> results);
  Future<List<GameResult>> loadResults();
  Future<OnlineRoom> createRoom();
  Future<OnlineRoom> joinRoom(String code);
  Future<OnlineRoom> getRoom(String code);
  Future<OnlineRoom> playMove(String code, int cell);
  Future<ChessRoom> createChessRoom();
  Future<ChessRoom> joinChessRoom(String code);
  Future<ChessRoom> getChessRoom(String code);
  Future<ChessRoom> playChessMove(
    String code,
    String fen, {
    required String status,
    String? winner,
  });
}
