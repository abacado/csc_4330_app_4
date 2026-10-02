import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csc_4330_app_4/core/arcade_controller.dart';
import 'package:csc_4330_app_4/games/minesweeper/minesweeper_engine.dart';
import 'package:csc_4330_app_4/games/minesweeper/minesweeper_screen.dart';
import 'package:csc_4330_app_4/services/local_store.dart';

void main() {
  Future<ArcadeController> launch(
    WidgetTester tester,
    MinesweeperEngine Function(MinesweeperDifficulty) newEngine,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = ArcadeController(
      store: LocalStore(await SharedPreferences.getInstance()),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MinesweeperScreen(controller: controller, newEngine: newEngine),
      ),
    );
    return controller;
  }

  Future<void> tapCell(WidgetTester tester, int cell) async {
    final finder = find.byKey(ValueKey('mine-cell-$cell'));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> longPressCell(WidgetTester tester, int cell) async {
    final finder = find.byKey(ValueKey('mine-cell-$cell'));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.longPress(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Revealing a mine ends the round as a loss', (tester) async {
    final controller = await launch(
      tester,
      (d) => MinesweeperEngine.fixed(difficulty: d, mines: {10}),
    );
    expect(find.textContaining('mines left'), findsOneWidget);
    await tapCell(tester, 10);
    expect(find.text('Boom — that was a mine.'), findsOneWidget);
    expect(controller.results.single.gameId, 'minesweeper');
    expect(controller.results.single.outcome, 'loss');
    expect(controller.results.single.mode, 'solo');
  });

  testWidgets('Clearing every safe square wins and records once', (
    tester,
  ) async {
    final controller = await launch(
      tester,
      (d) => MinesweeperEngine.fixed(difficulty: d, mines: {0}),
    );
    for (var cell = 1; cell < 64; cell++) {
      await tapCell(tester, cell);
    }
    expect(find.text('Board cleared!'), findsOneWidget);
    expect(controller.results.single.outcome, 'win');
    expect(controller.results.length, 1);
  });

  testWidgets('Long-pressing a hidden square flags it instead of revealing', (
    tester,
  ) async {
    await launch(
      tester,
      (d) => MinesweeperEngine.fixed(difficulty: d, mines: {10}),
    );
    await longPressCell(tester, 10);
    expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
    await tapCell(tester, 10); // flagged squares ignore taps
    expect(find.text('Boom — that was a mine.'), findsNothing);
  });

  testWidgets('Restarting mid-round asks for confirmation', (tester) async {
    await launch(
      tester,
      (d) => MinesweeperEngine.fixed(difficulty: d, mines: {10}),
    );
    await tapCell(tester, 0);
    await tester.tap(find.byTooltip('Restart game'));
    await tester.pumpAndSettle();
    expect(find.text('Start a new board?'), findsOneWidget);
    await tester.tap(find.text('Keep playing'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mine-cell-0')), findsOneWidget);
  });
}
