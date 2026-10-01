import 'package:flutter/material.dart';

import '../../theme/arcade_theme.dart';
import 'sudoku_engine.dart';

const _conflictColor = Color(0xFFFF819C);

class SudokuBoard extends StatelessWidget {
  const SudokuBoard({
    super.key,
    required this.engine,
    required this.selected,
    required this.conflicts,
    required this.accent,
    required this.onSelect,
  });
  final SudokuEngine engine;
  final int? selected;
  final Set<int> conflicts;
  final Color accent;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    final values = engine.values;
    final selectedValue = selected == null ? 0 : values[selected!];
    return Center(
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
                for (var row = 0; row < 9; row++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var col = 0; col < 9; col++)
                          Expanded(
                            child: _cell(
                              row * 9 + col,
                              values[row * 9 + col],
                              selectedValue,
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

  Widget _cell(int cell, int value, int selectedValue) {
    final row = rowOf(cell), col = colOf(cell);
    final isSelected = cell == selected;
    final isPeer = selected != null && peers[selected!].contains(cell);
    final sameNumber = value != 0 && value == selectedValue;
    final given = engine.isGiven(cell);
    final conflict = conflicts.contains(cell);
    final thin = BorderSide(color: arcadeMuted.withValues(alpha: 0.25));
    final thick = BorderSide(color: accent.withValues(alpha: 0.8), width: 2);
    return Semantics(
      button: true,
      label:
          'Row ${row + 1}, column ${col + 1}, ${value == 0 ? 'empty' : value}${given ? ', clue' : ''}${conflict ? ', conflict' : ''}',
      child: GestureDetector(
        key: ValueKey('sudoku-cell-$cell'),
        behavior: HitTestBehavior.opaque,
        onTap: onSelect == null ? null : () => onSelect!(cell),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.45)
                : sameNumber
                ? accent.withValues(alpha: 0.25)
                : isPeer
                ? arcadePanel
                : arcadeBackground,
            border: Border(
              right: col == 8 ? BorderSide.none : (col % 3 == 2 ? thick : thin),
              bottom: row == 8
                  ? BorderSide.none
                  : (row % 3 == 2 ? thick : thin),
            ),
          ),
          alignment: Alignment.center,
          child: value == 0
              ? null
              : FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: given ? FontWeight.w900 : FontWeight.w500,
                        color: conflict
                            ? _conflictColor
                            : given
                            ? arcadeMuted
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class SudokuNumberPad extends StatelessWidget {
  const SudokuNumberPad({
    super.key,
    required this.engine,
    required this.onDigit,
  });
  final SudokuEngine engine;

  /// Receives 1–9, or 0 to erase. Null disables the pad.
  final ValueChanged<int>? onDigit;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 450),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var d = 1; d <= 9; d++)
          SizedBox(
            width: 44,
            height: 52,
            child: FilledButton.tonal(
              key: ValueKey('sudoku-digit-$d'),
              style: FilledButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: onDigit == null ? null : () => onDigit!(d),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$d',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${(9 - engine.countOf(d)).clamp(0, 9)}',
                    style: const TextStyle(fontSize: 10, color: arcadeMuted),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(
          width: 96,
          height: 52,
          child: OutlinedButton.icon(
            key: const ValueKey('sudoku-erase'),
            style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: onDigit == null ? null : () => onDigit!(0),
            icon: const Icon(Icons.backspace_outlined, size: 18),
            label: const Text('Erase'),
          ),
        ),
      ],
    ),
  );
}
