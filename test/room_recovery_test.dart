import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csc_4330_app_4/core/arcade_controller.dart';
import 'package:csc_4330_app_4/games/chess/chess_online_room_screen.dart';
import 'package:csc_4330_app_4/games/tic_tac_toe/online_room_screen.dart';
import 'package:csc_4330_app_4/services/cloud_service.dart';
import 'package:csc_4330_app_4/services/local_store.dart';

import 'support/fake_cloud.dart';

void main() {
  for (final chess in [false, true]) {
    group(chess ? 'Chess recovery' : 'Tic-Tac-Toe recovery', () {
      late FakeCloud cloud;
      late ArcadeController controller;

      Future<void> launch(WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        cloud = FakeCloud();
        controller = ArcadeController(
          store: LocalStore(await SharedPreferences.getInstance()),
          cloud: cloud,
        );
        await controller.connect();
        await tester.pumpWidget(
          MaterialApp(
            home: chess
                ? ChessOnlineRoomScreen(controller: controller)
                : OnlineRoomScreen(controller: controller),
          ),
        );
      }

      void setRoom({String status = 'playing', String? winner}) {
        final json = <String, dynamic>{
          'code': 'ABC123',
          'host_id': 'host',
          'guest_id': 'guest',
          'status': status,
          'winner': winner,
          'board': List.filled(9, ''),
          'turn': 'X',
          'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        };
        cloud.room = OnlineRoom.fromJson(json);
        cloud.chessRoom = ChessRoom.fromJson(json);
      }

      Future<void> create(WidgetTester tester) async {
        await tester.tap(find.text('Create a room'));
        await tester.pumpAndSettle();
      }

      testWidgets('Room creation can be retried after a connection failure', (
        tester,
      ) async {
        await launch(tester);
        cloud.fail = true;
        await create(tester);
        expect(find.textContaining('Could not create a room.'), findsOneWidget);
        cloud.fail = false;
        await create(tester);
        expect(find.text('ROOM ABC123'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('Polling reports an outage and recovers automatically', (
        tester,
      ) async {
        await launch(tester);
        await create(tester);
        cloud.fail = true;
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        expect(find.textContaining('Connection interrupted.'), findsOneWidget);
        cloud.fail = false;
        setRoom();
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        expect(find.textContaining('Connection interrupted.'), findsNothing);
        expect(
          find.text(chess ? 'Your move — White' : 'Your move — X'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('Copy code sends the actual room code to the clipboard', (
        tester,
      ) async {
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await launch(tester);
        await create(tester);
        await tester.tap(find.text('Copy code'));
        await tester.pump();
        expect(copied, 'ABC123');
        expect(find.text('Room code copied'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('A rejected move is shown and reconnecting restores play', (
        tester,
      ) async {
        await launch(tester);
        setRoom();
        await create(tester);
        cloud.fail = true;
        if (chess) {
          final from = find.byKey(const ValueKey('square-12'));
          final to = find.byKey(const ValueKey('square-28'));
          await tester.ensureVisible(from);
          await tester.tap(from);
          await tester.pump();
          await tester.ensureVisible(to);
          await tester.tap(to);
        } else {
          await tester.tap(find.byKey(const ValueKey('cell-0')));
        }
        await tester.pump();
        expect(find.textContaining('Move not confirmed.'), findsOneWidget);
        expect(cloud.moves, isEmpty);
        expect(cloud.chessMoves, isEmpty);
        cloud.fail = false;
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        expect(find.textContaining('Move not confirmed.'), findsNothing);
        expect(
          find.text(chess ? 'Your move — White' : 'Your move — X'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('Background polling pauses and resuming refreshes the room', (
        tester,
      ) async {
        await launch(tester);
        await create(tester);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        setRoom();
        await tester.pump(const Duration(seconds: 4));
        expect(find.text('Waiting for your friend…'), findsOneWidget);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(
          find.text(chess ? 'Your move — White' : 'Your move — X'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
      });

      for (final outcome in ['win', 'loss', 'draw']) {
        testWidgets(
          'Finished $outcome is displayed and player can return to rooms',
          (tester) async {
            await launch(tester);
            await create(tester);
            setRoom(
              status: 'finished',
              winner: outcome == 'draw'
                  ? null
                  : outcome == 'win'
                  ? (chess ? 'white' : 'X')
                  : (chess ? 'black' : 'O'),
            );
            await tester.pump(const Duration(seconds: 2));
            await tester.pumpAndSettle();
            expect(
              find.text(
                outcome == 'draw'
                    ? 'It’s a draw!'
                    : outcome == 'win'
                    ? 'You won!'
                    : 'Your friend won!',
              ),
              findsOneWidget,
            );
            final back = find.text('Back to rooms');
            await tester.ensureVisible(back);
            await tester.tap(back);
            await tester.pumpAndSettle();
            expect(find.text('Create a room'), findsOneWidget);
            expect(find.text('ROOM ABC123'), findsNothing);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    });
  }
}
