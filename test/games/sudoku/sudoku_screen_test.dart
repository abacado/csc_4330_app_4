import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csc_4330_app_4/core/arcade_controller.dart';
import 'package:csc_4330_app_4/games/sudoku/sudoku_engine.dart';
import 'package:csc_4330_app_4/games/sudoku/sudoku_screen.dart';
import 'package:csc_4330_app_4/services/local_store.dart';

const solution =
    '534678912672195348198342567859761423426853791'
    '713924856961537284287419635345286179';

/// The solution with cells 2 and 3 (a 4 and a 6) left blank.
SudokuPuzzle nearlyDone(SudokuDifficulty _) {
  final digits = [for (final c in solution.split('')) int.parse(c)];
  return SudokuPuzzle(
    givens: List.of(digits)
      ..[2] = 0
      ..[3] = 0,
    solution: digits,
  );
}

void main() {
  Future<ArcadeController> launch(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = ArcadeController(
      store: LocalStore(await SharedPreferences.getInstance()),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SudokuScreen(controller: controller, newPuzzle: nearlyDone),
      ),
    );
    return controller;
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  String cellText(WidgetTester tester, int cell) {
    final text = find.descendant(
      of: find.byKey(ValueKey('sudoku-cell-$cell')),
      matching: find.byType(Text),
    );
    return text.evaluate().isEmpty ? '' : tester.widget<Text>(text).data!;
  }

  testWidgets('Conflicts show, can be erased, and solving records once', (
    tester,
  ) async {
    final controller = await launch(tester);
    expect(find.text('Pick a square to begin.'), findsOneWidget);

    await tapKey(tester, 'sudoku-cell-2');
    await tapKey(tester, 'sudoku-digit-6'); // 6 is already in that column
    expect(cellText(tester, 2), '6');
    expect(
      find.text('Something repeats — check the red squares.'),
      findsOneWidget,
    );

    await tapKey(tester, 'sudoku-erase');
    expect(cellText(tester, 2), '');
    await tapKey(tester, 'sudoku-digit-4');
    await tapKey(tester, 'sudoku-cell-3');
    await tapKey(tester, 'sudoku-digit-6');

    expect(find.text('Puzzle solved!'), findsOneWidget);
    expect(controller.results.single.gameId, 'sudoku');
    expect(controller.results.single.outcome, 'completed');
    expect(controller.results.single.mode, 'solo');

    await tapKey(tester, 'sudoku-cell-3'); // board is locked after solving
    expect(find.text('Puzzle solved!'), findsOneWidget);
    expect(controller.results.length, 1);

    await tester.ensureVisible(find.text('New puzzle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New puzzle'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a square to begin.'), findsOneWidget);
    expect(cellText(tester, 2), '');
  });

  testWidgets('Notes can be pencilled in, erased, and replaced by a number', (
    tester,
  ) async {
    await launch(tester);
    List<String> notes(int cell) => [
      for (final e
          in find
              .descendant(
                of: find.byKey(ValueKey('sudoku-notes-$cell')),
                matching: find.byType(Text),
              )
              .evaluate())
        (e.widget as Text).data!,
    ];

    await tapKey(tester, 'sudoku-notes-toggle');
    expect(find.text('Notes on'), findsOneWidget);
    await tapKey(tester, 'sudoku-cell-2');
    await tapKey(tester, 'sudoku-digit-4');
    await tapKey(tester, 'sudoku-digit-6');
    await tapKey(tester, 'sudoku-cell-3');
    await tapKey(tester, 'sudoku-digit-4');
    await tapKey(tester, 'sudoku-digit-6');
    expect(notes(2), ['4', '6']);
    expect(notes(3), ['4', '6']);

    await tapKey(tester, 'sudoku-erase'); // clears cell 3's notes
    expect(notes(3), isEmpty);

    await tapKey(tester, 'sudoku-notes-toggle');
    await tapKey(tester, 'sudoku-cell-2');
    await tapKey(tester, 'sudoku-digit-4');
    expect(notes(2), isEmpty);
    expect(cellText(tester, 2), '4');
  });

  testWidgets('Clue squares cannot be changed', (tester) async {
    await launch(tester);
    await tapKey(tester, 'sudoku-cell-0');
    await tapKey(tester, 'sudoku-digit-1');
    expect(cellText(tester, 0), '5');
  });

  testWidgets('Restarting mid-puzzle asks for confirmation', (tester) async {
    await launch(tester);
    await tapKey(tester, 'sudoku-cell-2');
    await tapKey(tester, 'sudoku-digit-4');
    await tester.tap(find.byTooltip('Restart game'));
    await tester.pumpAndSettle();
    expect(find.text('Start a new puzzle?'), findsOneWidget);
    await tester.tap(find.text('Keep playing'));
    await tester.pumpAndSettle();
    expect(cellText(tester, 2), '4');

    await tester.tap(find.byTooltip('Restart game'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'New puzzle'));
    await tester.pumpAndSettle();
    expect(cellText(tester, 2), '');
  });

  for (final size in [const Size(320, 640), const Size(1440, 900)]) {
    testWidgets('Fits a ${size.width.toInt()}px screen', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await launch(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
