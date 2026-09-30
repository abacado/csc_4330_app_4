import 'package:flutter/material.dart';

import '../../theme/arcade_theme.dart';

class TicTacToeBoard extends StatelessWidget {
  const TicTacToeBoard({super.key, required this.board, required this.onMove});
  final List<String> board;
  final ValueChanged<int>? onMove;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 390),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 9,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemBuilder: (context, cell) => Semantics(
          label:
              'Row ${cell ~/ 3 + 1}, column ${cell % 3 + 1}, ${board[cell].isEmpty ? 'empty' : board[cell]}',
          child: FilledButton(
            key: ValueKey('cell-$cell'),
            style: FilledButton.styleFrom(
              backgroundColor: arcadePanel,
              disabledBackgroundColor: arcadePanel,
              disabledForegroundColor: board[cell] == 'X'
                  ? arcadeMint
                  : const Color(0xFFFF819C),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: onMove != null && board[cell].isEmpty
                ? () => onMove!(cell)
                : null,
            child: FittedBox(
              child: Text(
                board[cell],
                style: const TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
