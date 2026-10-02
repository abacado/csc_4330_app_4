import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/game_result.dart';

class LocalStore {
  LocalStore(this.preferences);
  final SharedPreferences preferences;
  String get name => preferences.getString('guest_name') ?? 'Player One';
  Future<void> saveName(String name) async {
    if (!await preferences.setString('guest_name', name)) {
      throw StateError('Could not save name');
    }
  }

  /// Highest score reached in a score-based game, or 0 if none yet.
  int bestScore(String gameId) => preferences.getInt('best_score_$gameId') ?? 0;
  Future<void> saveBestScore(String gameId, int score) async {
    if (!await preferences.setInt('best_score_$gameId', score)) {
      throw StateError('Could not save best score');
    }
  }

  List<GameResult> loadResults() {
    final results = <GameResult>[];
    for (final value in preferences.getStringList('results') ?? <String>[]) {
      try {
        results.add(
          GameResult.fromJson(jsonDecode(value) as Map<String, dynamic>),
        );
      } on Object {
        /* A damaged entry must not hide the other saved games. */
      }
    }
    return results;
  }

  Future<void> saveResults(List<GameResult> results) async {
    if (!await preferences.setStringList(
      'results',
      results.map((r) => jsonEncode(r.toJson())).toList(),
    )) {
      throw StateError('Could not save results');
    }
  }
}
