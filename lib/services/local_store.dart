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
