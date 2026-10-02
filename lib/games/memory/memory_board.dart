import 'package:flutter/material.dart';

import '../../theme/arcade_theme.dart';
import 'memory_engine.dart';

/// Card faces, indexed by symbol. A deck can use up to this many pairs.
const memorySymbols = <IconData>[
  Icons.star_rounded,
  Icons.favorite_rounded,
  Icons.bolt_rounded,
  Icons.rocket_launch_rounded,
  Icons.pets_rounded,
  Icons.music_note_rounded,
  Icons.wb_sunny_rounded,
  Icons.sports_esports_rounded,
];

const _symbolNames = [
  'star',
  'heart',
  'bolt',
  'rocket',
  'paw',
  'music note',
  'sun',
  'controller',
];

class MemoryBoard extends StatelessWidget {
  const MemoryBoard({
    super.key,
    required this.engine,
    required this.accent,
    required this.onFlip,
  });
  final MemoryEngine engine;
  final Color accent;
  final ValueChanged<int>? onFlip;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: engine.cardCount,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemBuilder: (context, index) => _card(index),
      ),
    ),
  );

  Widget _card(int index) {
    final faceUp = engine.isFaceUp(index);
    final matched = engine.isMatched(index);
    final symbol = engine.symbols[index];
    final canFlip = onFlip != null && !faceUp && !engine.hasMismatch;
    return Semantics(
      button: true,
      label: faceUp
          ? 'Card ${index + 1}, ${_symbolNames[symbol]}'
                '${matched ? ', matched' : ''}'
          : 'Card ${index + 1}, face down',
      child: FilledButton(
        key: ValueKey('memory-card-$index'),
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: arcadePanel,
          disabledBackgroundColor: faceUp
              ? accent.withValues(alpha: matched ? 0.18 : 0.32)
              : arcadePanel,
          disabledForegroundColor: matched ? accent : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: faceUp ? accent : arcadeMuted.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
        ),
        onPressed: canFlip ? () => onFlip!(index) : null,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: faceUp
              ? Icon(
                  memorySymbols[symbol],
                  key: ValueKey('face-$index'),
                  size: 36,
                )
              : Text(
                  '?',
                  key: ValueKey('back-$index'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: arcadeMuted,
                  ),
                ),
        ),
      ),
    );
  }
}
