import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csc_4330_app_4/core/arcade_controller.dart';
import 'package:csc_4330_app_4/games/checkers/checkers_engine.dart';
import 'package:csc_4330_app_4/games/checkers/checkers_screen.dart';
import 'package:csc_4330_app_4/services/local_store.dart';

int sq(int row, int col) => row * 8 + col;

void main() {
  Future<ArcadeController> launch(
    WidgetTester tester, [
    CheckersEngine Function()? newEngine,
  ]) async {
    SharedPreferences.setMockInitialValues({});
    final controller = ArcadeController(
      store: LocalStore(await SharedPreferences.getInstance()),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CheckersScreen(controller: controller, newEngine: newEngine),
      ),
    );
    return controller;
  }

  Future<void> tapSquare(WidgetTester tester, int square) async {
    final finder = find.byKey(ValueKey('checkers-square-$square'));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Selecting a piece and moving it passes the turn', (
    tester,
  ) async {
    await launch(tester);
    expect(find.text("Black's turn"), findsOneWidget);
    await tapSquare(tester, sq(2, 1));
    await tapSquare(tester, sq(3, 0));
    expect(find.text("Red's turn"), findsOneWidget);
    expect(find.text('BLACK 12   •   RED 12'), findsOneWidget);
  });

  testWidgets('A required jump blocks other moves until taken', (tester) async {
    await launch(
      tester,
      () => CheckersEngine.fromPieces({
        sq(2, 1): const Piece(Side.black),
        sq(2, 5): const Piece(Side.black),
        sq(3, 2): const Piece(Side.red),
        sq(7, 0): const Piece(Side.red),
      }),
    );
    expect(find.text('Black must jump'), findsOneWidget);

    await tapSquare(tester, sq(2, 5));
    expect(
      find.text('A jump is available, and jumps are required.'),
      findsOneWidget,
    );

    await tapSquare(tester, sq(2, 1));
    await tapSquare(tester, sq(4, 3));
    expect(find.text("Red's turn"), findsOneWidget);
    expect(find.text('BLACK 2   •   RED 1'), findsOneWidget);
  });

  testWidgets('Capturing the last piece wins and records once', (tester) async {
    final controller = await launch(
      tester,
      () => CheckersEngine.fromPieces({
        sq(2, 1): const Piece(Side.black),
        sq(3, 2): const Piece(Side.red),
      }),
    );
    await tapSquare(tester, sq(2, 1));
    await tapSquare(tester, sq(4, 3));
    expect(find.text('Black wins!'), findsOneWidget);
    expect(controller.results.length, 1);
    expect(controller.results.single.gameId, 'checkers');
    expect(controller.results.single.mode, 'local');

    await tester.ensureVisible(find.text('Play again'));
    await tester.tap(find.text('Play again'));
    await tester.pumpAndSettle();
    expect(find.text('Black must jump'), findsOneWidget);
    expect(controller.results.length, 1);
  });

  testWidgets('Restarting mid-game asks first', (tester) async {
    await launch(tester);
    await tapSquare(tester, sq(2, 1));
    await tapSquare(tester, sq(3, 0));

    await tester.tap(find.byTooltip('Restart game'));
    await tester.pumpAndSettle();
    expect(find.text('Start a new game?'), findsOneWidget);
    await tester.tap(find.text('Keep playing'));
    await tester.pumpAndSettle();
    expect(find.text("Red's turn"), findsOneWidget);

    await tester.tap(find.byTooltip('Restart game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    expect(find.text("Black's turn"), findsOneWidget);
  });
}
