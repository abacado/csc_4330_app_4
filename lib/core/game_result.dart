class GameResult {
  const GameResult({
    required this.id,
    required this.gameId,
    required this.outcome,
    required this.mode,
    required this.completedAt,
  });
  final String id, gameId, outcome, mode;
  final DateTime completedAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'game_id': gameId,
    'outcome': outcome,
    'mode': mode,
    'completed_at': completedAt.toUtc().toIso8601String(),
  };
  factory GameResult.fromJson(Map<String, dynamic> json) => GameResult(
    id: json['id'] as String,
    gameId: json['game_id'] as String,
    outcome: json['outcome'] as String,
    mode: json['mode'] as String,
    completedAt: DateTime.parse(json['completed_at'] as String),
  );
}
