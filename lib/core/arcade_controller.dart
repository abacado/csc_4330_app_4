import 'package:flutter/foundation.dart';

import '../services/cloud_service.dart';
import '../services/local_store.dart';
import 'game_result.dart';

enum CloudStatus { local, connecting, connected, unavailable }

class ArcadeController extends ChangeNotifier {
  ArcadeController({required this.store, this.cloud})
    : name = store.name,
      results = store.loadResults();
  final LocalStore store;
  final CloudService? cloud;
  String name;
  List<GameResult> results;
  CloudStatus status = CloudStatus.local;
  String? notice;
  bool _syncing = false;

  Future<void> rename(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 20) return;
    await store.saveName(trimmed);
    name = trimmed;
    notifyListeners();
  }

  Future<void> connect() async {
    if (cloud == null || _syncing) return;
    _syncing = true;
    status = CloudStatus.connecting;
    notice = null;
    notifyListeners();
    try {
      await cloud!.connect().timeout(const Duration(seconds: 20));
      await _sync();
      status = CloudStatus.connected;
    } on Object {
      status = CloudStatus.unavailable;
      notice =
          'Cloud connection unavailable. You can still play on this device.';
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> recordResult(GameResult result) async {
    if (results.any((item) => item.id == result.id)) return;
    results = [result, ...results].take(100).toList();
    try {
      await store.saveResults(results);
      notice = null;
    } on Object {
      notice =
          'This result is visible now, but could not be saved on this device.';
    }
    notifyListeners();
    if (status == CloudStatus.connected) await refreshHistory();
  }

  Future<void> refreshHistory() async {
    if (cloud == null || _syncing) return;
    _syncing = true;
    try {
      await _sync();
      status = CloudStatus.connected;
      notice = null;
    } on Object {
      status = CloudStatus.unavailable;
      notice = 'Cloud sync paused. Your local results are still here. Try reconnecting.';
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _sync() async {
    await cloud!.saveResults(results).timeout(const Duration(seconds: 15));
    final remote = await cloud!.loadResults().timeout(
      const Duration(seconds: 15),
    );
    final merged = {
      for (final r in results) r.id: r,
      for (final r in remote) r.id: r,
    }.values.toList()..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    results = merged.take(100).toList();
    await store.saveResults(results);
  }
}
