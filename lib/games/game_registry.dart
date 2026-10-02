import 'package:flutter/material.dart';

import '../core/arcade_controller.dart';
import 'chess/chess_screen.dart';
import 'checkers/checkers_screen.dart';
import 'sudoku/sudoku_screen.dart';
import 'word_search/word_search_screen.dart';
import 'tic_tac_toe/tic_tac_toe_screen.dart';
import 'memory/memory_screen.dart';
import 'minesweeper/minesweeper_screen.dart';

// Teammates own their screen; keep navigation centralized here.
Widget gameScreen(String id, ArcadeController controller) => switch (id) {
  'chess' => ChessScreen(controller: controller),
  'checkers' => CheckersScreen(controller: controller),
  'sudoku' => SudokuScreen(controller: controller),
  'word_search' => WordSearchScreen(controller: controller),
  'tic_tac_toe' => TicTacToeScreen(controller: controller),
  'memory' => MemoryScreen(controller: controller),
  'minesweeper' => MinesweeperScreen(controller: controller),
  _ => throw ArgumentError.value(id, 'id', 'Unknown game'),
};
