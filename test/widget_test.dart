import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csc_4330_app_4/app.dart';
import 'package:csc_4330_app_4/core/arcade_controller.dart';
import 'package:csc_4330_app_4/services/local_store.dart';

void main() {
  Future<ArcadeController> launch(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = ArcadeController(
      store: LocalStore(await SharedPreferences.getInstance()),
    );
    await tester.pumpWidget(PocketArcadeApp(controller: controller));
    return controller;
  }

  testWidgets('Arcade opens without cloud configuration or a debug banner', (
    tester,
  ) async {
    await launch(tester);
    expect(find.text('Arcade'), findsOneWidget);
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .debugShowCheckedModeBanner,
      isFalse,
    );
    expect(find.text('Memory'), findsOneWidget);
  });

  testWidgets('Puzzle filter shows Memory and hides Chess', (tester) async {
    await launch(tester);
    await tester.ensureVisible(find.text('Puzzles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Puzzles'));
    await tester.pumpAndSettle();
    expect(find.text('Memory'), findsOneWidget);
    expect(find.text('Chess'), findsNothing);
    expect(find.text('Sudoku'), findsOneWidget);
  });

  testWidgets('Online filter shows only room-code games and can be cleared', (
    tester,
  ) async {
    await launch(tester);
    await tester.ensureVisible(find.text('Online'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Online'));
    await tester.pumpAndSettle();
    for (final name in ['Chess', 'Checkers', 'Tic-Tac-Toe']) {
      expect(find.text(name), findsOneWidget);
    }
    for (final name in ['Memory', 'Sudoku', 'Word Search']) {
      expect(find.text(name), findsNothing);
    }
    await tester.tap(find.text('Puzzles'));
    await tester.pumpAndSettle();
    expect(find.text('Memory'), findsOneWidget);
    expect(find.text('Checkers'), findsNothing);
    await tester.tap(find.text('All games'));
    await tester.pumpAndSettle();
    expect(find.text('Checkers'), findsOneWidget);
    expect(find.text('Memory'), findsOneWidget);
  });

  testWidgets('A local winning round is saved once and can be restarted', (
    tester,
  ) async {
    final controller = await launch(tester);
    await tester.tap(find.text('Play Tic-Tac-Toe'));
    await tester.pumpAndSettle();
    for (final cell in [0, 3, 1, 4, 2]) {
      await tester.tap(find.byKey(ValueKey('cell-$cell')));
      await tester.pumpAndSettle();
    }
    expect(find.text('X takes the round!'), findsOneWidget);
    expect(controller.results.length, 1);
    expect(controller.results.single.outcome, 'completed');
    await tester.ensureVisible(find.text('One more round'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('One more round'));
    await tester.pumpAndSettle();
    expect(find.text('X — your move'), findsOneWidget);
    expect(controller.results.length, 1);
  });

  testWidgets('Instructions open and a game returns to the arcade', (
    tester,
  ) async {
    await launch(tester);
    await tester.ensureVisible(find.text('Checkers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Checkers'));
    await tester.pumpAndSettle();
    expect(find.text("Black's turn"), findsOneWidget);
    await tester.tap(find.byTooltip('How to play'));
    await tester.pumpAndSettle();
    expect(find.text('How to play Checkers'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Arcade'), findsOneWidget);
  });

  testWidgets('Guest can rename and view empty history', (tester) async {
    final controller = await launch(tester);
    await tester.tap(find.text('Player'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Pixel Pal');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(controller.name, 'Pixel Pal');
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Your next round starts the story.'), findsOneWidget);
    expect(find.text('PLAYING ON THIS DEVICE'), findsOneWidget);
  });

  for (final size in [const Size(320, 640), const Size(1440, 900)]) {
    testWidgets('Home and game fit ${size.width.toInt()}px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await launch(tester);

      await tester.ensureVisible(find.text('Play Tic-Tac-Toe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play Tic-Tac-Toe'));
      await tester.pumpAndSettle();
    });
  }
}
