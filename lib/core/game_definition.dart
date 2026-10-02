import 'package:flutter/material.dart';

enum GameCategory { strategy, puzzles }

class GameDefinition {
  const GameDefinition({
    required this.id,
    required this.name,
    required this.tagline,
    required this.instructions,
    required this.icon,
    required this.color,
    required this.category,
    required this.players,
    this.ready = false,
  });
  final String id, name, tagline, instructions, players;
  final IconData icon;
  final Color color;
  final GameCategory category;
  final bool ready;
}

const games = <GameDefinition>[
  GameDefinition(
    id: 'chess',
    name: 'Chess',
    tagline: 'Think ahead. Rule the board.',
    instructions: 'Take turns moving one piece. Protect your king and checkmate your opponent. White moves first.',
    icon: Icons.castle_outlined,
    color: Color(0xFFFFCA75),
    category: GameCategory.strategy,
    players: '2 players',
    ready: true,
  ),
  GameDefinition(
    id: 'checkers',
    name: 'Checkers',
    tagline: 'Small moves. Big comebacks.',
    instructions: 'Move diagonally across the dark squares. Jump opposing pieces to capture them and reach the far edge to become a king.',
    icon: Icons.blur_circular,
    color: Color(0xFFFF819C),
    category: GameCategory.strategy,
    players: '2 players',
    ready: true,
  ),
  GameDefinition(
    id: 'sudoku',
    name: 'Sudoku',
    tagline: 'Find your focus, one square at a time.',
    instructions: 'Fill each row, column, and 3 × 3 box with the numbers 1 through 9, without repeating a number.',
    icon: Icons.grid_on_rounded,
    color: Color(0xFFAB9BFF),
    category: GameCategory.puzzles,
    players: 'Solo',
    ready: true,
  ),
  GameDefinition(
    id: 'word_search',
    name: 'Word Search',
    tagline: 'A little curiosity goes a long way.',
    instructions: 'Find the hidden words in the letter grid. Select the first and last letters of a word to mark it.',
    icon: Icons.manage_search_rounded,
    color: Color(0xFF75DBFF),
    category: GameCategory.puzzles,
    players: 'Solo',
    ready: true,
  ),
  GameDefinition(
    id: 'tic_tac_toe',
    name: 'Tic-Tac-Toe',
    tagline: 'Three in a row. One more round.',
    instructions: 'X goes first. Take turns choosing an empty square. Connect three marks across, down, or diagonally to win. A full board without a winner is a draw.',
    icon: Icons.tag_rounded,
    color: Color(0xFF8EE6BD),
    category: GameCategory.strategy,
    players: '2 players',
    ready: true,
  ),
  GameDefinition(
    id: 'memory',
    name: 'Memory',
    tagline: 'Flip. Remember. Find your match.',
    instructions: 'Flip two cards at a time. Matching pairs stay face up. Remember what you see and find every pair.',
    icon: Icons.style_outlined,
    color: Color(0xFFF6A5E6),
    category: GameCategory.puzzles,
    players: 'Solo',
    ready: true,
  ),
];

GameDefinition gameById(String id) => games.firstWhere((game) => game.id == id);
