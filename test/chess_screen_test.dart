import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csc_4330_app_4/core/arcade_controller.dart';
import 'package:csc_4330_app_4/games/chess/chess_screen.dart';
import 'package:csc_4330_app_4/services/local_store.dart';

void main() {
  Future<ArcadeController> launch(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = ArcadeController(
      store: LocalStore(await SharedPreferences.getInstance()),
    );
    await tester.pumpWidget(
      MaterialApp(home: ChessScreen(controller: controller)),
    );
    return controller;
  }

  Future<void> tapSquare(WidgetTester tester, int square) async {
    final finder = find.byKey(ValueKey('square-$square'));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Pass & Play opens on the standard position', (tester) async {
    await launch(tester);
    expect(find.text('White to move'), findsOneWidget);
    expect(find.text('Pass & Play'), findsOneWidget);
  });

  testWidgets("Fool's mate ends the game and restart resets the board", (
    tester,
  ) async {
    final controller = await launch(tester);
    await tapSquare(tester, 13); // select f2
    await tapSquare(tester, 21); // f2-f3
    await tapSquare(tester, 52); // select e7
    await tapSquare(tester, 36); // e7-e5
    await tapSquare(tester, 14); // select g2
    await tapSquare(tester, 30); // g2-g4
    await tapSquare(tester, 59); // select d8
    await tapSquare(tester, 31); // Qd8-h4#
    expect(find.text('Black wins by checkmate!'), findsOneWidget);
    expect(controller.results.single.outcome, 'completed');
    expect(controller.results.single.gameId, 'chess');
    await tester.ensureVisible(find.text('New game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    expect(find.text('White to move'), findsOneWidget);
  });

  testWidgets('An illegal destination tap is ignored', (tester) async {
    await launch(tester);
    await tapSquare(tester, 12); // select e2
    await tapSquare(
      tester,
      12 + 24,
    ); // tap a non-target square (e6, unreachable)
    expect(find.text('White to move'), findsOneWidget);
  });

  testWidgets('Switching to vs Bot resets the board', (tester) async {
    await launch(tester);
    await tester.ensureVisible(find.text('vs Bot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vs Bot'));
    await tester.pumpAndSettle();
    expect(find.text('White to move'), findsOneWidget);
  });
}
