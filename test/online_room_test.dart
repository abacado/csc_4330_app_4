import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csc_4330_app_4/core/arcade_controller.dart';
import 'package:csc_4330_app_4/games/tic_tac_toe/online_room_screen.dart';
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
      MaterialApp(home: OnlineRoomScreen(controller: controller)),
    );
  }

  testWidgets('Invalid room code stays on form', (tester) async {
    await launch(tester);
    await tester.tap(find.text('Join room'));
    await tester.pump();
    expect(find.text('Enter the six-character room code.'), findsOneWidget);
    expect(cloud.joinedCode, isNull);
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
          .widget<FilledButton>(find.byKey(const ValueKey('cell-0')))
          .onPressed,
      isNull,
    );
    cloud.room = OnlineRoom.fromJson({
      'code': 'ABC123',
      'host_id': 'host',
      'guest_id': 'guest',
      'board': List.filled(9, ''),
      'turn': 'X',
      'status': 'playing',
      'winner': null,
    });
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Your move — X'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cell-0')));
    await tester.pump();
    expect(cloud.moves, [0]);
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
    expect(cloud.joinedCode, 'ABC123');
    await tester.pumpWidget(const SizedBox());
  });
}
