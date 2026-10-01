import 'package:flutter/material.dart';

import '../../theme/arcade_theme.dart';

const _glyphs = {
  'K': '♔', 'Q': '♕', 'R': '♖', 'B': '♗', 'N': '♘', 'P': '♙',
  'k': '♚', 'q': '♛', 'r': '♜', 'b': '♝', 'n': '♞', 'p': '♟',
};
const _lightSquare = Color(0xFF2B3050);
const _darkSquare = Color(0xFF1C2033);
const _checkSquare = Color(0xFFFF819C);

int squareAt(int row, int col, bool flipped) {
  final rank = flipped ? row : 7 - row;
  final file = flipped ? 7 - col : col;
  return rank * 8 + file;
}

class ChessBoard extends StatelessWidget {
  const ChessBoard({
    super.key,
    required this.board,
    required this.onTap,
    this.selected,
    this.legalTargets = const {},
    this.checkSquare,
    this.flipped = false,
  });
  final List<String> board;
  final ValueChanged<int>? onTap;
  final int? selected;
  final Set<int> legalTargets;
  final int? checkSquare;
  final bool flipped;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 64,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
          itemBuilder: (context, index) {
            final row = index ~/ 8, col = index % 8;
            final square = squareAt(row, col, flipped);
            final piece = board[square];
            final isLight = (row + col) % 2 == 0;
            final isSelected = selected == square;
            final isTarget = legalTargets.contains(square);
            final isChecked = checkSquare == square;
            return Semantics(
              label: '${_squareName(square)}${piece.isEmpty ? '' : ', $piece'}',
              child: GestureDetector(
                key: ValueKey('square-$square'),
                onTap: onTap == null ? null : () => onTap!(square),
                child: Container(
                  color: isChecked
                      ? _checkSquare
                      : isSelected
                      ? arcadeMint.withValues(alpha: 0.55)
                      : isLight
                      ? _lightSquare
                      : _darkSquare,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (piece.isNotEmpty)
                        FittedBox(
                          child: Text(
                            _glyphs[piece] ?? '',
                            style: TextStyle(
                              fontSize: 40,
                              color: piece == piece.toUpperCase() ? Colors.white : const Color(0xFF0E0F1A),
                            ),
                          ),
                        ),
                      if (isTarget)
                        Container(
                          margin: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: arcadeMint.withValues(alpha: piece.isEmpty ? 0.5 : 0.0),
                            border: piece.isNotEmpty
                                ? Border.all(color: arcadeMint, width: 3)
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  static String _squareName(int square) =>
      '${String.fromCharCode(97 + square % 8)}${square ~/ 8 + 1}';
}

/// Shows a picker for the four promotion pieces; returns null if dismissed.
Future<String?> askPromotionChoice(BuildContext context, String color) => showDialog<String>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Promote pawn to'),
    content: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final piece in const ['Q', 'R', 'B', 'N'])
          IconButton(
            iconSize: 36,
            onPressed: () => Navigator.pop(context, piece),
            icon: Text(
              _glyphs[color == 'white' ? piece : piece.toLowerCase()] ?? '',
              style: const TextStyle(fontSize: 32),
            ),
          ),
      ],
    ),
  ),
);
