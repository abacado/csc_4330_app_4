import 'package:flutter/material.dart';

import '../../theme/arcade_theme.dart';
import 'game_2048_engine.dart';

/// Tile background by value; anything past 2048 reuses the last color.
const _tileColors = {
  2: Color(0xFF2E3550),
  4: Color(0xFF3A4366),
  8: Color(0xFF6BCBFF),
  16: Color(0xFF75DBFF),
  32: Color(0xFF8EE6BD),
  64: Color(0xFFC8F27A),
  128: Color(0xFFFFE27A),
  256: Color(0xFFFFCA75),
  512: Color(0xFFFFB86B),
  1024: Color(0xFFFF819C),
  2048: Color(0xFFF6A5E6),
};

/// Swipes shorter than this (in logical pixels per second) are ignored.
const _minSwipeVelocity = 100.0;

class Game2048Board extends StatelessWidget {
  const Game2048Board({
    super.key,
    required this.engine,
    required this.accent,
    required this.onSlide,
  });
  final Game2048Engine engine;
  final Color accent;

  /// Called with the swipe direction; null while input is locked.
  final ValueChanged<SlideDirection>? onSlide;

  void _horizontal(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v.abs() < _minSwipeVelocity) return;
    onSlide?.call(v < 0 ? SlideDirection.left : SlideDirection.right);
  }

  void _vertical(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v.abs() < _minSwipeVelocity) return;
    onSlide?.call(v < 0 ? SlideDirection.up : SlideDirection.down);
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 450),
      child: AspectRatio(
        aspectRatio: 1,
        child: GestureDetector(
          key: const ValueKey('game-2048-board'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: onSlide == null ? null : _horizontal,
          onVerticalDragEnd: onSlide == null ? null : _vertical,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: arcadePanel,
              border: Border.all(color: accent, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                for (var row = 0; row < Game2048Engine.size; row++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var col = 0; col < Game2048Engine.size; col++)
                          Expanded(
                            child: _tile(
                              row * Game2048Engine.size + col,
                              engine.tileAt(row, col),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _tile(int cell, int value) => Semantics(
    label: value == 0 ? 'Empty' : '$value',
    child: AnimatedContainer(
      key: ValueKey('tile-$cell'),
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: value == 0
            ? arcadeBackground
            : _tileColors[value] ?? _tileColors[2048],
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: value == 0
          ? null
          : FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    // Light text on the dark low tiles, dark on bright ones.
                    color: value <= 4 ? Colors.white : arcadeBackground,
                  ),
                ),
              ),
            ),
    ),
  );
}
