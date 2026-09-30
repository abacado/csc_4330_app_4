import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/arcade_controller.dart';
import '../../core/game_definition.dart';
import '../../services/cloud_service.dart';
import '../../theme/arcade_theme.dart';
import '../../widgets/game_scaffold.dart';
import 'tic_tac_toe_board.dart';

class OnlineRoomScreen extends StatefulWidget {
  const OnlineRoomScreen({super.key, required this.controller});
  final ArcadeController controller;
  @override
  State<OnlineRoomScreen> createState() => _OnlineRoomScreenState();
}

class _OnlineRoomScreenState extends State<OnlineRoomScreen>
    with WidgetsBindingObserver {
  final _code = TextEditingController();
  OnlineRoom? _room;
  Timer? _poller;
  bool _busy = false;
  bool _polling = false;
  bool _stale = false;
  bool _active = true;
  String? _error;
  CloudService get cloud => widget.controller.cloud!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) unawaited(_refresh());
  }

  void _accept(OnlineRoom room) {
    final wasFinished = _room?.status == 'finished';
    setState(() {
      _room = room;
      _stale = false;
      _error = null;
    });
    if (room.status == 'finished' && !wasFinished) {
      _poller?.cancel();
      unawaited(widget.controller.refreshHistory());
    }
  }

  Future<void> _enter(bool create) async {
    final code = _code.text.trim().toUpperCase();
    if (!create && !RegExp(r'^[A-F0-9]{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the six-character room code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final room = create
          ? await cloud.createRoom()
          : await cloud.joinRoom(code);
      if (!mounted) return;
      _accept(room);
      _poller?.cancel();
      if (room.status != 'finished') {
        _poller = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
      }
    } on Object {
      if (mounted) {
        setState(
          () => _error = create
              ? 'Could not create a room. Check your connection and try again.'
              : 'Could not join. Check the code; the room may be full or expired.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    if (_room == null || _busy || _polling || !_active) return;
    _polling = true;
    try {
      final room = await cloud.getRoom(_room!.code);
      if (mounted) _accept(room);
    } on Object {
      if (mounted) {
        setState(() {
          _stale = true;
          _error = 'Connection interrupted. Retrying automatically…';
        });
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _move(int cell) async {
    if (_busy || _polling || _room == null) return;
    setState(() => _busy = true);
    try {
      final room = await cloud.playMove(_room!.code, cell);
      if (mounted) _accept(room);
    } on Object {
      if (mounted) {
        setState(() {
          _stale = true;
          _error = 'Move not confirmed. Reconnecting before the next turn…';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final mark = room?.markFor(cloud.userId);
    final canMove =
        room?.status == 'playing' && room?.turn == mark && !_busy && !_stale;
    return GameScaffold(
      game: gameById('tic_tac_toe'),
      child: Column(
        children: [
          const Text(
            'ACROSS THE ARCADE',
            style: TextStyle(color: arcadeMint, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          if (room == null) ...[
            Text(
              'A friend is one code away.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Create a private room, or join a friend on another device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: arcadeMuted, height: 1.6),
            ),
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: _busy ? null : () => _enter(true),
              icon: const Icon(Icons.add),
              label: const Text('Create a room'),
            ),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'OR JOIN A FRIEND',
                style: TextStyle(color: arcadeMuted, fontSize: 12),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: TextField(
                controller: _code,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Room code',
                  hintText: 'A1B2C3',
                ),
                onSubmitted: (_) {
                  if (!_busy) _enter(false);
                },
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : () => _enter(false),
              child: const Text('Join room'),
            ),
          ] else ...[
            Text(
              'ROOM ${room.code}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: room.code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Room code copied')),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy code'),
            ),
            const SizedBox(height: 8),
            Text(
              room.status == 'waiting'
                  ? 'Waiting for your friend…'
                  : room.status == 'finished'
                  ? room.winner == null
                        ? 'It’s a draw!'
                        : room.winner == mark
                        ? 'You won!'
                        : 'Your friend won!'
                  : room.turn == mark
                  ? 'Your move — $mark'
                  : 'Your friend’s move',
              style: const TextStyle(color: arcadeMint, fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You are $mark. Rooms last 24 hours.',
              style: const TextStyle(color: arcadeMuted, fontSize: 12),
            ),
            const SizedBox(height: 22),
            TicTacToeBoard(board: room.board, onMove: canMove ? _move : null),
            const SizedBox(height: 20),
            if (room.status == 'finished')
              OutlinedButton(
                onPressed: () {
                  _poller?.cancel();
                  setState(() {
                    _room = null;
                    _code.clear();
                  });
                },
                child: const Text('Back to rooms'),
              ),
            const SizedBox(height: 12),
            const Text(
              'Keep this screen open during your match. To return, join with the same room code on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: arcadeMuted, fontSize: 12, height: 1.5),
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFFCA75), height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
