import 'package:flutter/material.dart';

import '../../theme/arcade_theme.dart';
import 'word_search_engine.dart';

/// Highlight colors cycled through as words are found.
const foundColors = [
  Color(0xFF75DBFF),
  Color(0xFF8EE6BD),
  Color(0xFFFFCA75),
  Color(0xFFF6A5E6),
  Color(0xFFAB9BFF),
  Color(0xFFFF819C),
];

class WordSearchBoard extends StatelessWidget {
  const WordSearchBoard({
    super.key,
    required this.engine,
    required this.anchor,
    required this.onTapCell,
  });
  final WordSearchEngine engine;

  /// The first letter of an in-progress selection.
  final int? anchor;
  final ValueChanged<int>? onTapCell;

  @override
  Widget build(BuildContext context) {
    final puzzle = engine.puzzle;
    final size = puzzle.size;
    final colorOf = <int, Color>{};
    final found = engine.found;
    for (var i = 0; i < found.length; i++) {
      for (final cell in found[i].cells) {
        colorOf[cell] = foundColors[i % foundColors.length];
      }
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: arcadePanel,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (var row = 0; row < size; row++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var col = 0; col < size; col++)
                          Expanded(
                            child: _cell(
                              row * size + col,
                              puzzle.grid[row * size + col],
                              colorOf[row * size + col],
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

  Widget _cell(int cell, String letter, Color? foundColor) {
    final size = engine.puzzle.size;
    final isAnchor = cell == anchor;
    return Semantics(
      button: true,
      label:
          'Row ${cell ~/ size + 1}, column ${cell % size + 1}, $letter${isAnchor ? ', selected' : ''}',
      child: GestureDetector(
        key: ValueKey('letter-$cell'),
        behavior: HitTestBehavior.opaque,
        onTap: onTapCell == null ? null : () => onTapCell!(cell),
        child: Container(
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: isAnchor
                ? Colors.white
                : foundColor?.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
            border: foundColor == null
                ? null
                : Border.all(color: foundColor.withValues(alpha: 0.8)),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isAnchor ? arcadeBackground : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
