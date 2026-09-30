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
}
