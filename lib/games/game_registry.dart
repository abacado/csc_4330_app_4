import 'package:flutter/material.dart';

import '../core/arcade_controller.dart';
import 'chess/chess_screen.dart';
import 'checkers/checkers_screen.dart';
import 'sudoku/sudoku_screen.dart';
import 'word_search/word_search_screen.dart';
import 'tic_tac_toe/tic_tac_toe_screen.dart';
import 'memory/memory_screen.dart';

// Teammates own their screen; keep navigation centralized here.
Widget gameScreen(String id, ArcadeController controller) => switch (id) {
  'chess' => const ChessScreen(),
  'checkers' => const CheckersScreen(),
  'sudoku' => const SudokuScreen(),
  'word_search' => const WordSearchScreen(),
  'tic_tac_toe' => TicTacToeScreen(controller: controller),
  'memory' => const MemoryScreen(),
  _ => throw ArgumentError.value(id, 'id', 'Unknown game'),
};
