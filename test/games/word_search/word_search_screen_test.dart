import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csc_4330_app_4/core/arcade_controller.dart';
import 'package:csc_4330_app_4/games/word_search/word_search_engine.dart';
import 'package:csc_4330_app_4/games/word_search/word_search_screen.dart';
import 'package:csc_4330_app_4/services/local_store.dart';

WordSearchPuzzle sample() => WordSearchPuzzle.fromRows(
  ['CATSX', 'XDOGX', 'XXXXX', 'BIRDX', 'XXXXX'],
  ['CAT', 'DOG', 'BIRD'],
  theme: 'Pets',
);

void main() {
  Future<ArcadeController> launch(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = ArcadeController(
      store: LocalStore(await SharedPreferences.getInstance()),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: WordSearchScreen(controller: controller, newPuzzle: sample),
      ),
    );
    return controller;
  }

  Future<void> select(WidgetTester tester, int from, int to) async {
    for (final cell in [from, to]) {
      final finder = find.byKey(ValueKey('letter-$cell'));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('Finding every word completes the puzzle once', (tester) async {
    final controller = await launch(tester);
    expect(find.text('THEME • PETS'), findsOneWidget);
    expect(find.text('0 of 3 found'), findsOneWidget);

    await select(tester, 6, 8);
    expect(find.text('Found DOG!'), findsOneWidget);
    await select(tester, 8, 6);
    expect(find.text('You already found that one.'), findsOneWidget);
    await select(tester, 0, 7);
    expect(
      find.text('Words run in straight lines across, down, or diagonally.'),
      findsOneWidget,
    );
    await select(tester, 0, 3);
    expect(find.text('Not a word on the list. Try again.'), findsOneWidget);
    expect(find.text('1 of 3 found'), findsOneWidget);

    await select(tester, 2, 0);
    await select(tester, 15, 18);
    expect(find.text('You found every word!'), findsOneWidget);
    expect(controller.results.single.gameId, 'word_search');
    expect(controller.results.single.mode, 'solo');

    await tester.ensureVisible(find.text('New puzzle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New puzzle'));
    await tester.pumpAndSettle();
    expect(find.text('0 of 3 found'), findsOneWidget);
    expect(controller.results.length, 1);
  });

  testWidgets('Tapping the same letter twice clears the selection', (
    tester,
  ) async {
    await launch(tester);
    await select(tester, 4, 4);
    expect(
      find.text('Selection cleared. Tap the first letter of a word.'),
      findsOneWidget,
    );
  });

  testWidgets('Restarting mid-puzzle asks for confirmation', (tester) async {
    await launch(tester);
    await select(tester, 6, 8);
    await tester.tap(find.byTooltip('Restart game'));
    await tester.pumpAndSettle();
    expect(find.text('Start a new puzzle?'), findsOneWidget);
    await tester.tap(find.text('Keep playing'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 3 found'), findsOneWidget);
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
