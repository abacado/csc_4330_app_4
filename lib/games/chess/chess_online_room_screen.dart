import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/arcade_controller.dart';
import '../../core/game_definition.dart';
import '../../services/cloud_service.dart';
import '../../theme/arcade_theme.dart';
import '../../widgets/game_scaffold.dart';
import 'chess_board.dart';
import 'chess_engine.dart';

class ChessOnlineRoomScreen extends StatefulWidget {
  const ChessOnlineRoomScreen({super.key, required this.controller});
  final ArcadeController controller;
  @override
  State<ChessOnlineRoomScreen> createState() => _ChessOnlineRoomScreenState();
}

class _ChessOnlineRoomScreenState extends State<ChessOnlineRoomScreen>
    with WidgetsBindingObserver {
  final _code = TextEditingController();
  ChessRoom? _room;
  Timer? _poller;
  bool _busy = false;
  bool _polling = false;
  bool _stale = false;
  bool _active = true;
  String? _error;
  int? _selected;
  Set<int> _targets = {};
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

  void _accept(ChessRoom room) {
    final wasFinished = _room?.status == 'finished';
    setState(() {
      _room = room;
      _stale = false;
      _error = null;
      _selected = null;
      _targets = {};
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
          ? await cloud.createChessRoom()
          : await cloud.joinChessRoom(code);
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
      final room = await cloud.getChessRoom(_room!.code);
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

  Future<void> _tap(int square) async {
    final room = _room;
    final color = room?.colorFor(cloud.userId);
    if (room == null || color == null || _busy || _polling || _stale) return;
    final engine = ChessEngine.fromFen(room.fen);
    if (room.status != 'playing' || room.turn != color) return;
    final piece = engine.board[square];
    final sideCode = color == 'white' ? 'w' : 'b';
    final ownPiece = piece.isNotEmpty && ChessEngine.colorOf(piece) == sideCode;
    if (_selected == null) {
      if (ownPiece) {
        setState(() {
          _selected = square;
          _targets = engine.movesFrom(square).map((m) => m.to).toSet();
        });
      }
      return;
    }
    if (square == _selected) {
      setState(() {
        _selected = null;
        _targets = {};
      });
      return;
    }
    if (_targets.contains(square)) {
      await _move(engine, _selected!, square);
      return;
    }
    setState(() {
      if (ownPiece) {
        _selected = square;
        _targets = engine.movesFrom(square).map((m) => m.to).toSet();
      } else {
        _selected = null;
        _targets = {};
      }
    });
  }

  Future<void> _move(ChessEngine engine, int from, int to) async {
    final color = _room!.colorFor(cloud.userId);
    final needsPromotion = engine
        .movesFrom(from)
        .any((m) => m.to == to && m.promotion != null);
    String? promotion;
    if (needsPromotion) {
      promotion = await askPromotionChoice(context, color!);
      if (promotion == null || !mounted) return;
    }
    final working = ChessEngine.fromFen(engine.toFen());
    if (!working.makeMove(from, to, promotion: promotion)) return;
    setState(() {
      _busy = true;
      _selected = null;
      _targets = {};
    });
    try {
      final status = working.isFinished ? 'finished' : 'playing';
      final winner = working.isCheckmate
          ? (working.winner == 'w' ? 'white' : 'black')
          : null;
      final room = await cloud.playChessMove(
        _room!.code,
        working.toFen(),
        status: status,
        winner: winner,
      );
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
    final color = room?.colorFor(cloud.userId);
    final engine = room == null ? null : ChessEngine.fromFen(room.fen);
    final canMove =
        room?.status == 'playing' && room?.turn == color && !_busy && !_stale;
    return GameScaffold(
      game: gameById('chess'),
      child: Column(
        children: [
          const Text(
            'ACROSS THE ARCADE',
            style: TextStyle(color: arcadeMint, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          if (room == null || engine == null) ...[
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
                        : room.winner == color
                        ? 'You won!'
                        : 'Your friend won!'
                  : room.turn == color
                  ? 'Your move — ${color == 'white' ? 'White' : 'Black'}'
                  : 'Your friend’s move',
              style: const TextStyle(color: arcadeMint, fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You are ${color ?? 'spectating'}. Rooms last 24 hours.',
              style: const TextStyle(color: arcadeMuted, fontSize: 12),
            ),
            const SizedBox(height: 22),
            ChessBoard(
              board: engine.board,
              selected: _selected,
              legalTargets: _targets,
              flipped: color == 'black',
              checkSquare: engine.isCheck
                  ? engine.board.indexOf(engine.turn == 'w' ? 'K' : 'k')
                  : null,
              onTap: canMove ? _tap : null,
            ),
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
