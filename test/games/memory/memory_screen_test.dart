import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csc_4330_app_4/core/arcade_controller.dart';
import 'package:csc_4330_app_4/games/memory/memory_engine.dart';
import 'package:csc_4330_app_4/games/memory/memory_screen.dart';
import 'package:csc_4330_app_4/services/local_store.dart';

// Longer than the tap ripple animation, so pumpAndSettle after a flip
// cannot run the mismatch timer by accident.
const delay = Duration(seconds: 5);

void main() {
  // Cards 0 and 2 match, 1 and 3 match.
  Future<ArcadeController> launch(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = ArcadeController(
      store: LocalStore(await SharedPreferences.getInstance()),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MemoryScreen(
          controller: controller,
          newEngine: () => MemoryEngine.fromSymbols([0, 1, 0, 1]),
          mismatchDelay: delay,
        ),
      ),
    );
    return controller;
  }

  Future<void> flip(WidgetTester tester, int card) async {
    await tester.tap(find.byKey(ValueKey('memory-card-$card')));
    await tester.pumpAndSettle();
  }

  bool faceUp(int card) =>
      find.byKey(ValueKey('face-$card')).evaluate().isNotEmpty;

  testWidgets('A mismatch locks the board, then hides after a delay', (
    tester,
  ) async {
    await launch(tester);
    expect(find.text('Flip two cards to find a pair.'), findsOneWidget);

    await flip(tester, 0);
    await flip(tester, 1);
    expect(find.text('Not a match. Remember them!'), findsOneWidget);
    expect(find.text('MOVES 1   •   PAIRS 0/2'), findsOneWidget);

    await flip(tester, 2); // locked while the mismatch is showing
    expect(faceUp(2), isFalse);

    await tester.pump(delay);
    await tester.pumpAndSettle();
    expect(faceUp(0), isFalse);
    expect(faceUp(1), isFalse);
    expect(find.text('Flip two cards to find a pair.'), findsOneWidget);
  });

  testWidgets('Finding every pair completes and records once', (tester) async {
    final controller = await launch(tester);
    await flip(tester, 0);
    await flip(tester, 2);
    expect(faceUp(0), isTrue);
    expect(faceUp(2), isTrue);
    await flip(tester, 1);
    await flip(tester, 3);

    expect(find.text('All pairs found in 2 moves!'), findsOneWidget);
    expect(controller.results.length, 1);
    expect(controller.results.single.gameId, 'memory');
    expect(controller.results.single.outcome, 'completed');

    await tester.ensureVisible(find.text('Play again'));
    await tester.tap(find.text('Play again'));
    await tester.pumpAndSettle();
    expect(find.text('MOVES 0   •   PAIRS 0/2'), findsOneWidget);
    expect(faceUp(0), isFalse);
    expect(controller.results.length, 1);
  });

  testWidgets('Restarting mid-game asks before reshuffling', (tester) async {
    await launch(tester);
    await flip(tester, 0);

    await tester.tap(find.byTooltip('Restart game'));
    await tester.pumpAndSettle();
    expect(find.text('Start a new game?'), findsOneWidget);
    await tester.tap(find.text('Keep playing'));
    await tester.pumpAndSettle();
    expect(faceUp(0), isTrue);

    await tester.tap(find.byTooltip('Restart game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    expect(faceUp(0), isFalse);
  });

  testWidgets('Leaving during a mismatch cancels the hide timer', (
    tester,
  ) async {
    await launch(tester);
    await flip(tester, 0);
    await flip(tester, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(delay); // would throw if the timer touched the screen
  });
}
