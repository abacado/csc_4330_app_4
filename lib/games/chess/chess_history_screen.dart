import 'package:flutter/material.dart';

import '../../core/arcade_controller.dart';
import '../../core/game_result.dart';
import '../../theme/arcade_theme.dart';
import 'chess_replay_screen.dart';

/// Lists finished chess games that recorded a move-by-move FEN history,
/// so a player can open one and step through it in [ChessReplayScreen].
class ChessHistoryScreen extends StatelessWidget {
  const ChessHistoryScreen({super.key, required this.controller});
  final ArcadeController controller;

  List<GameResult> _reviewable() => controller.results
      .where((r) => r.gameId == 'chess' && (r.moves?.length ?? 0) > 1)
      .toList();

  String _date(DateTime value) {
    final date = value.toLocal();
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _summary(GameResult result) => switch (result.outcome) {
    'win' => 'You won',
    'loss' => 'You lost',
    'draw' => 'Draw',
    _ => 'Completed',
  };

  @override
  Widget build(BuildContext context) {
    final games = _reviewable();
    return Scaffold(
      appBar: AppBar(title: const Text('Past chess games')),
      body: SafeArea(
        child: games.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Finish a Pass & Play or vs Bot game to review it here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: arcadeMuted),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: games.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final result = games[index];
                  return Card(
                    color: arcadePanel,
                    child: ListTile(
                      leading: const Icon(
                        Icons.castle_outlined,
                        color: arcadeMint,
                      ),
                      title: Text(_summary(result)),
                      subtitle: Text(
                        '${result.mode == 'local' ? 'Pass & Play / vs Bot' : result.mode} · '
                        '${(result.moves!.length - 1)} ply · ${_date(result.completedAt)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ChessReplayScreen(result: result),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
