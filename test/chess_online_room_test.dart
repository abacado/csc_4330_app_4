import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csc_4330_app_4/core/arcade_controller.dart';
import 'package:csc_4330_app_4/games/chess/chess_online_room_screen.dart';
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
      MaterialApp(home: ChessOnlineRoomScreen(controller: controller)),
    );
  }

  testWidgets('Invalid room code stays on form', (tester) async {
    await launch(tester);
    await tester.tap(find.text('Join room'));
    await tester.pump();
    expect(find.text('Enter the six-character room code.'), findsOneWidget);
    expect(cloud.joinedChessCode, isNull);
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
          .widget<GestureDetector>(find.byKey(const ValueKey('square-12')))
          .onTap,
      isNull,
    );
    cloud.chessRoom = ChessRoom.fromJson({
      'code': 'ABC123',
      'host_id': 'host',
      'guest_id': 'guest',
      'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      'status': 'playing',
      'winner': null,
    });
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Your move — White'), findsOneWidget);
    final from = find.byKey(const ValueKey('square-12'));
    final to = find.byKey(const ValueKey('square-28'));
    await tester.ensureVisible(from);
    await tester.pumpAndSettle();
    await tester.tap(from); // select e2
    await tester.pump();
    await tester.ensureVisible(to);
    await tester.pumpAndSettle();
    await tester.tap(to); // e2-e4
    await tester.pump();
    expect(cloud.chessMoves, hasLength(1));
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
    expect(cloud.joinedChessCode, 'ABC123');
    await tester.pumpWidget(const SizedBox());
  });
}
