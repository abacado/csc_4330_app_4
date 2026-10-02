import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csc_4330_app_4/core/arcade_controller.dart';
import 'package:csc_4330_app_4/games/checkers/checkers_online_room_screen.dart';
import 'package:csc_4330_app_4/services/local_store.dart';
import 'package:csc_4330_app_4/services/cloud_service.dart';

import 'support/fake_cloud.dart';

void main() {
  late FakeCloud cloud;
  Future<void> launch(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    cloud = FakeCloud();
    final controller = ArcadeController(
      store: LocalStore(await SharedPreferences.getInstance()),
      cloud: cloud,
    );
    await controller.connect();
    await tester.pumpWidget(
      MaterialApp(home: CheckersOnlineRoomScreen(controller: controller)),
    );
  }

  testWidgets('Invalid room code stays on form', (tester) async {
    await launch(tester);
    await tester.tap(find.text('Join room'));
    await tester.pump();
    expect(find.text('Enter the six-character room code.'), findsOneWidget);
    expect(cloud.joinedCheckersCode, isNull);
  });

  testWidgets('Joining as Red disables moves on Black turn', (tester) async {
    await launch(tester);
    cloud.checkersRoom = CheckersRoom.fromJson({
      'code': 'ABC123',
      'host_id': 'friend',
      'guest_id': 'host',
      'board': cloud.checkersRoom.board,
      'turn': 'black',
      'jumper': null,
      'status': 'playing',
      'winner': null,
      'revision': 0,
    });
    await tester.enterText(find.byType(TextField), 'abc123');
    await tester.tap(find.text('Join room'));
    await tester.pumpAndSettle();
    expect(find.text('Your friend’s move'), findsOneWidget);
    expect(
      tester
          .widget<InkWell>(find.byKey(const ValueKey('checkers-square-40')))
          .onTap,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Rejoining a multiple jump restores the forced piece and revision',
    (tester) async {
      await launch(tester);
      final board = List.filled(64, 0);
      board[35] = 1;
      board[44] = -1;
      cloud.checkersRoom = CheckersRoom.fromJson({
        'code': 'ABC123',
        'host_id': 'host',
        'guest_id': 'friend',
        'board': board,
        'turn': 'black',
        'jumper': 35,
        'status': 'playing',
        'winner': null,
        'revision': 7,
      });
      await tester.enterText(find.byType(TextField), 'ABC123');
      await tester.tap(find.text('Join room'));
      await tester.pumpAndSettle();
      expect(
        find.text('Keep jumping with the highlighted piece.'),
        findsOneWidget,
      );
      final destination = find.byKey(const ValueKey('checkers-square-53'));
      await tester.ensureVisible(destination);
      await tester.tap(destination);
      await tester.pump();
      expect(cloud.checkersMoves, [
        [35, 53, 7],
      ]);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Unchanged polls preserve piece selection', (tester) async {
    await launch(tester);
    cloud.checkersRoom = CheckersRoom.fromJson({
      'code': 'ABC123',
      'host_id': 'host',
      'guest_id': 'friend',
      'board': cloud.checkersRoom.board,
      'turn': 'black',
      'jumper': null,
      'status': 'playing',
      'winner': null,
      'revision': 0,
    });
    await tester.tap(find.text('Create a room'));
    await tester.pumpAndSettle();
    final source = find.byKey(const ValueKey('checkers-square-17'));
    await tester.ensureVisible(source);
    await tester.tap(source);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    final destination = find.byKey(const ValueKey('checkers-square-24'));
    await tester.ensureVisible(destination);
    await tester.tap(destination);
    await tester.pump();
    expect(cloud.checkersMoves, [
      [17, 24, 0],
    ]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Room creation waits for guest and polling enables host turn', (
    tester,
  ) async {
    await launch(tester);
    await tester.tap(find.text('Create a room'));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for your friend…'), findsOneWidget);
    expect(
      tester
          .widget<InkWell>(find.byKey(const ValueKey('checkers-square-17')))
          .onTap,
      isNull,
    );
    cloud.checkersRoom = CheckersRoom.fromJson({
      'code': 'ABC123',
      'host_id': 'host',
      'guest_id': 'guest',
      'board': cloud.checkersRoom.board,
      'turn': 'black',
      'jumper': null,
      'revision': 0,
      'status': 'playing',
      'winner': null,
    });
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Your move — Black'), findsOneWidget);
    final from = find.byKey(const ValueKey('checkers-square-17'));
    final to = find.byKey(const ValueKey('checkers-square-24'));
    await tester.ensureVisible(from);
    await tester.pumpAndSettle();
    await tester.tap(from); // select Black piece
    await tester.pump();
    await tester.ensureVisible(to);
    await tester.pumpAndSettle();
    await tester.tap(to); // first Black move
    await tester.pump();
    expect(cloud.checkersMoves, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Join normalizes lowercase code and failures can be retried', (
    tester,
  ) async {
    await launch(tester);
    cloud.fail = true;
    await tester.enterText(find.byType(TextField), 'abc123');
    await tester.tap(find.text('Join room'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not join.'), findsOneWidget);
    cloud.fail = false;
    await tester.tap(find.text('Join room'));
    await tester.pumpAndSettle();
    expect(cloud.joinedCheckersCode, 'ABC123');
    await tester.pumpWidget(const SizedBox());
  });
}
