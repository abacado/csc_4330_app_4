import 'package:flutter/material.dart';

import '../../theme/arcade_theme.dart';
import 'minesweeper_engine.dart';

const _numberColors = {
  1: Color(0xFF6BCBFF),
  2: Color(0xFF8EE6BD),
  3: Color(0xFFFF819C),
  4: Color(0xFFAB9BFF),
  5: Color(0xFFFFCA75),
  6: Color(0xFF75DBFF),
  7: Colors.white,
  8: arcadeMuted,
};

class MinesweeperBoard extends StatelessWidget {
  const MinesweeperBoard({
    super.key,
    required this.engine,
    required this.accent,
    required this.onReveal,
    required this.onFlag,
  });
  final MinesweeperEngine engine;
  final Color accent;
  final ValueChanged<int>? onReveal;
  final ValueChanged<int>? onFlag;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 450),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: accent, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var row = 0; row < engine.rows; row++)
                Expanded(
                  child: Row(
                    children: [
                      for (var col = 0; col < engine.cols; col++)
                        Expanded(child: _cell(row * engine.cols + col)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _cell(int cell) {
    final revealed = engine.isRevealed(cell);
    final flagged = engine.isFlagged(cell);
    final mine = engine.isMine(cell);
    final count = revealed && !mine ? engine.adjacentMines(cell) : 0;
    final showMine = revealed && mine;
    return Semantics(
      button: true,
      label: flagged
          ? 'Flagged'
          : !revealed
          ? 'Hidden square'
          : mine
          ? 'Mine'
          : count == 0
          ? 'Empty'
          : '$count adjacent mines',
      child: GestureDetector(
        key: ValueKey('mine-cell-$cell'),
        behavior: HitTestBehavior.opaque,
        onTap: onReveal == null || revealed ? null : () => onReveal!(cell),
        onLongPress: onFlag == null || revealed ? null : () => onFlag!(cell),
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: revealed ? arcadeBackground : arcadePanel,
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.center,
          child: showMine
              ? const Icon(Icons.dangerous_rounded, color: Color(0xFFFF819C))
              : flagged
              ? Icon(Icons.flag_rounded, color: accent, size: 18)
              : count == 0
              ? null
              : FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _numberColors[count] ?? Colors.white,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
