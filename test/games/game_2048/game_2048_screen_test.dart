import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csc_4330_app_4/core/arcade_controller.dart';
import 'package:csc_4330_app_4/games/game_2048/game_2048_engine.dart';
import 'package:csc_4330_app_4/games/game_2048/game_2048_screen.dart';
import 'package:csc_4330_app_4/services/local_store.dart';

void main() {
  Future<ArcadeController> launch(
    WidgetTester tester,
    List<int> tiles, {
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final controller = ArcadeController(
      store: LocalStore(await SharedPreferences.getInstance()),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Game2048Screen(
          controller: controller,
          newEngine: () => Game2048Engine.fromTiles(tiles, random: Random(1)),
        ),
      ),
    );
    return controller;
  }

  Future<void> swipe(WidgetTester tester, Offset offset) async {
    await tester.fling(
      find.byKey(const ValueKey('game-2048-board')),
      offset,
      1000,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  String scoreText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('game-2048-score'))).data!;

  final pair = [
    0, 2, 2, 0, //
    0, 0, 0, 0, //
    0, 0, 0, 0, //
    0, 0, 0, 0, //
  ];

  testWidgets('Swiping left merges a pair and updates score and best', (
    tester,
  ) async {
    final controller = await launch(tester, pair);
    expect(scoreText(tester), 'SCORE 0   •   BEST 0');

    await swipe(tester, const Offset(-300, 0));
    expect(scoreText(tester), 'SCORE 4   •   BEST 4');
    expect(controller.store.bestScore('game_2048'), 4);
  });

  testWidgets('Arrow keys slide the tiles too', (tester) async {
    await launch(tester, pair);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(scoreText(tester), 'SCORE 4   •   BEST 4');
  });

  testWidgets('A saved best score is shown and kept when beaten later', (
    tester,
  ) async {
    await launch(tester, pair, prefs: {'best_score_game_2048': 500});
    expect(scoreText(tester), 'SCORE 0   •   BEST 500');
    await swipe(tester, const Offset(0, 300));
    expect(scoreText(tester), 'SCORE 0   •   BEST 500');
  });

  testWidgets('Reaching 2048 records one win and offers Keep going', (
    tester,
  ) async {
    final controller = await launch(tester, [
      1024, 1024, 0, 0, //
      0, 0, 0, 0, //
      0, 0, 0, 0, //
      0, 0, 0, 0, //
    ]);
    await swipe(tester, const Offset(-300, 0));
    expect(find.text('You made 2048!'), findsOneWidget);
    expect(controller.results.single.outcome, 'win');

    await tapButton(tester, 'Keep going');
    expect(find.text('Merge tiles to reach 2048.'), findsOneWidget);

    // Playing on after the win does not save a second result.
    await swipe(tester, const Offset(0, 300));
    expect(controller.results, hasLength(1));
  });

  testWidgets('Locking up the board records a loss and New game resets', (
    tester,
  ) async {
    // Sliding left merges the two 2s; whatever tile spawns in the one gap
    // (2 or 4) has no equal neighbor, so the board is stuck.
    final controller = await launch(tester, [
      2, 2, 8, 16, //
      8, 16, 32, 64, //
      16, 32, 64, 128, //
      32, 64, 128, 256, //
    ]);
    await swipe(tester, const Offset(-300, 0));
    expect(find.text('No moves left.'), findsOneWidget);
    expect(controller.results.single.outcome, 'loss');

    await tapButton(tester, 'New game');
    expect(find.text('Merge tiles to reach 2048.'), findsOneWidget);
    expect(scoreText(tester), startsWith('SCORE 0'));
  });
}
