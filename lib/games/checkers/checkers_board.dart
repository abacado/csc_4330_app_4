import 'package:flutter/material.dart';

import '../../theme/arcade_theme.dart';
import 'checkers_engine.dart';

const redPieceColor = Color(0xFFFF5A6E);
const blackPieceColor = Color(0xFF2B2F45);
const _lightSquare = Color(0xFF3A3F5C);
const _darkSquare = arcadePanel;

class CheckersBoard extends StatelessWidget {
  const CheckersBoard({
    super.key,
    required this.engine,
    required this.selected,
    required this.accent,
    required this.onTap,
  });
  final CheckersEngine engine;
  final int? selected;
  final Color accent;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final legal = engine.legalMoves;
    final movable = {for (final m in legal) m.from};
    final targets = {
      for (final m in legal)
        if (m.from == selected) m.to,
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                for (var row = 0; row < 8; row++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var col = 0; col < 8; col++)
                          Expanded(
                            child: _square(
                              row * 8 + col,
                              movable: movable,
                              targets: targets,
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
    );
  }

  Widget _square(
    int square, {
    required Set<int> movable,
    required Set<int> targets,
  }) {
    if (!isDarkSquare(square)) {
      return const ColoredBox(color: _lightSquare);
    }
    final piece = engine.pieceAt(square);
    final isSelected = square == selected;
    final isTarget = targets.contains(square);
    final canMove = movable.contains(square) && !engine.isOver;
    final name = piece == null
        ? 'empty'
        : '${piece.side.label}${piece.king ? ' king' : ''}';
    return Semantics(
      button: onTap != null,
      label:
          'Row ${rowOf(square) + 1}, column ${colOf(square) + 1}, $name'
          '${isTarget ? ', move here' : ''}',
      child: Material(
        color: isSelected ? accent.withValues(alpha: 0.35) : _darkSquare,
        child: InkWell(
          key: ValueKey('checkers-square-$square'),
          onTap: onTap == null ? null : () => onTap!(square),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isTarget)
                FractionallySizedBox(
                  widthFactor: 0.32,
                  heightFactor: 0.32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              if (piece != null) _piece(piece, highlight: canMove),
            ],
          ),
        ),
      ),
    );
  }

  Widget _piece(Piece piece, {required bool highlight}) => FractionallySizedBox(
    widthFactor: 0.78,
    heightFactor: 0.78,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: piece.side == Side.red ? redPieceColor : blackPieceColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: highlight ? accent : arcadeMuted.withValues(alpha: 0.5),
          width: highlight ? 3 : 1.5,
        ),
      ),
      child: piece.king
          ? const FittedBox(
              child: Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.star_rounded, color: Colors.white),
              ),
            )
          : null,
    ),
  );
}
