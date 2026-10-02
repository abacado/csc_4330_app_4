import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/game_result.dart';
import 'cloud_service.dart';

class SupabaseService implements CloudService {
  SupabaseService(this.url, this.key);
  final String url, key;
  SupabaseClient? _client;
  SupabaseClient get client => _client!;
  static SupabaseService? fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    return url.isEmpty || key.isEmpty ? null : SupabaseService(url, key);
  }

  @override
  String get userId => client.auth.currentUser!.id;
  @override
  Future<CheckersRoom> createCheckersRoom() =>
      _checkersRpc('create_checkers_room', {});
  @override
  Future<CheckersRoom> joinCheckersRoom(String code) =>
      _checkersRpc('join_checkers_room', {'room_code': code});
  @override
  Future<CheckersRoom> playCheckersMove(
    String code,
    int from,
    int to,
    int revision,
  ) => _checkersRpc('play_checkers_move', {
    'room_code': code,
    'from_square': from,
    'to_square': to,
    'expected_revision': revision,
  });
  Future<CheckersRoom> _checkersRpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    final row = await client
        .rpc(name, params: params)
        .timeout(const Duration(seconds: 15));
    return CheckersRoom.fromJson(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<CheckersRoom> getCheckersRoom(String code) async {
    final row = await client
        .from('checkers_rooms')
        .select()
        .eq('code', code)
        .single()
        .timeout(const Duration(seconds: 10));
    return CheckersRoom.fromJson(row);
  }

  @override
  Future<void> connect() async {
    if (_client == null) {
      await Supabase.initialize(url: url, publishableKey: key);
      _client = Supabase.instance.client;
    }
    if (client.auth.currentSession == null) {
      await client.auth.signInAnonymously();
    }
  }

  @override
  Future<void> saveResults(List<GameResult> results) async {
    // Online results are written only by the server's move function.
    final local = results.where((r) => r.mode != 'online').toList();
    if (local.isEmpty) return;
    await client
        .from('game_results')
        .upsert(
          local.map((r) => {...r.toJson(), 'user_id': userId}).toList(),
          onConflict: 'id',
          ignoreDuplicates: true,
        );
  }

  @override
  Future<List<GameResult>> loadResults() async {
    final rows = await client
        .from('game_results')
        .select()
        .eq('user_id', userId)
        .order('completed_at', ascending: false)
        .limit(100);
    return rows.map(GameResult.fromJson).toList();
  }

  @override
  Future<OnlineRoom> createRoom() => _rpc('create_room', {});
  @override
  Future<OnlineRoom> joinRoom(String code) =>
      _rpc('join_room', {'room_code': code});
  @override
  Future<OnlineRoom> playMove(String code, int cell) =>
      _rpc('play_move', {'room_code': code, 'cell_index': cell});
  Future<OnlineRoom> _rpc(String name, Map<String, dynamic> params) async {
    final row = await client
        .rpc(name, params: params)
        .timeout(const Duration(seconds: 15));
    return OnlineRoom.fromJson(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<OnlineRoom> getRoom(String code) async {
    final row = await client
        .from('rooms')
        .select()
        .eq('code', code)
        .single()
        .timeout(const Duration(seconds: 10));
    return OnlineRoom.fromJson(row);
  }

  @override
  Future<ChessRoom> createChessRoom() => _chessRpc('create_chess_room', {});
  @override
  Future<ChessRoom> joinChessRoom(String code) =>
      _chessRpc('join_chess_room', {'room_code': code});
  @override
  Future<ChessRoom> playChessMove(
    String code,
    String fen, {
    required String status,
    String? winner,
  }) => _chessRpc('play_chess_move', {
    'room_code': code,
    'new_fen': fen,
    'new_status': status,
    'new_winner': winner,
  });
  Future<ChessRoom> _chessRpc(String name, Map<String, dynamic> params) async {
    final row = await client
        .rpc(name, params: params)
        .timeout(const Duration(seconds: 15));
    return ChessRoom.fromJson(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<ChessRoom> getChessRoom(String code) async {
    final row = await client
        .from('chess_rooms')
        .select()
        .eq('code', code)
        .single()
        .timeout(const Duration(seconds: 10));
    return ChessRoom.fromJson(row);
  }
}
