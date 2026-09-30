import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csc_4330_app_4/core/arcade_controller.dart';
import 'package:csc_4330_app_4/core/game_result.dart';
import 'package:csc_4330_app_4/services/local_store.dart';

import 'support/fake_cloud.dart';

void main() {
  late LocalStore store;
  late FakeCloud cloud;
  late ArcadeController controller;
  final result = GameResult(
    id: 'round-1',
    gameId: 'memory',
    outcome: 'completed',
    mode: 'solo',
    completedAt: DateTime.utc(2026, 9, 30),
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = LocalStore(await SharedPreferences.getInstance());
    cloud = FakeCloud();
    controller = ArcadeController(store: store, cloud: cloud);
  });
  test('No configured backend remains local', () async {
    final local = ArcadeController(store: store);
    await local.connect();
    expect(local.status, CloudStatus.local);
  });
  test('Guest name persists and rejects empty or long names', () async {
    await controller.rename('  Pixel  ');
    expect(store.name, 'Pixel');
    await controller.rename(' ');
    await controller.rename('a' * 21);
    expect(controller.name, 'Pixel');
  });
  test(
    'Completed rounds persist and duplicate callbacks are idempotent',
    () async {
      await controller.recordResult(result);
      await controller.recordResult(result);
      expect(controller.results.length, 1);
      expect(ArcadeController(store: store).results.single.id, result.id);
    },
  );
  test(
    'Offline results sync on connection and merge without duplicates',
    () async {
      await controller.recordResult(result);
      await controller.connect();
      expect(controller.status, CloudStatus.connected);
      expect(cloud.saved.length, 1);
      await controller.refreshHistory();
      expect(controller.results.length, 1);
    },
  );
  test('Connection failure preserves local play; retry succeeds', () async {
    cloud.fail = true;
    await controller.connect();
    expect(controller.status, CloudStatus.unavailable);
    await controller.recordResult(result);
    expect(store.loadResults().length, 1);
    cloud.fail = false;
    await controller.connect();
    expect(controller.status, CloudStatus.connected);
    expect(cloud.saved.length, 1);
  });
  test('Sync failure does not discard a finished round', () async {
    await controller.connect();
    cloud.fail = true;
    await controller.recordResult(result);
    expect(controller.status, CloudStatus.unavailable);
    expect(store.loadResults().single.id, result.id);
  });
  test('Damaged local entry does not hide valid saved results', () async {
    await controller.recordResult(result);
    final entries = store.preferences.getStringList('results')!;
    await store.preferences.setStringList('results', [
      'broken json',
      ...entries,
    ]);
    expect(store.loadResults().single.id, result.id);
  });
  test('Result serialization preserves UTC timestamp', () {
    expect(
      GameResult.fromJson(result.toJson()).completedAt,
      result.completedAt,
    );
  });
}
