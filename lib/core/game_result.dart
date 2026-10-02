class GameResult {
  const GameResult({
    required this.id,
    required this.gameId,
    required this.outcome,
    required this.mode,
    required this.completedAt,
    this.moves,
  });
  final String id, gameId, outcome, mode;
  final DateTime completedAt;
  /// FEN position after each ply, starting with the opening position.
  /// Only populated for games that support move-by-move review (chess).
  final List<String>? moves;
  Map<String, dynamic> toJson() => {
    'id': id,
    'game_id': gameId,
    'outcome': outcome,
    'mode': mode,
    'completed_at': completedAt.toUtc().toIso8601String(),
    if (moves != null) 'moves': moves,
  };
  factory GameResult.fromJson(Map<String, dynamic> json) => GameResult(
    id: json['id'] as String,
    gameId: json['game_id'] as String,
    outcome: json['outcome'] as String,
    mode: json['mode'] as String,
    completedAt: DateTime.parse(json['completed_at'] as String),
    moves: (json['moves'] as List?)?.cast<String>(),
  );
}
