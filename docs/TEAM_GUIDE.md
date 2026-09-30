# Teammate integration guide

## Start here

Each person owns two game folders under `lib/games/`. Assign ownership before editing. Leave shared navigation, theme, cloud services, and schema to the framework owner unless coordinated.

| Game | Folder | Current status |
| --- | --- | --- |
| Chess | `lib/games/chess/` | Starter screen |
| Checkers | `lib/games/checkers/` | Starter screen |
| Sudoku | `lib/games/sudoku/` | Starter screen |
| Word Search | `lib/games/word_search/` | Starter screen |
| Tic-Tac-Toe | `lib/games/tic_tac_toe/` | Playable integration reference, local + online |
| Memory | `lib/games/memory/` | Starter screen |

Tic-Tac-Toe's owner can extend and polish the reference instead of rebuilding it. Online play for other games is outside the initial scope.

## Build a game

1. Replace your `GameStarter` with a `GameScaffold`. Keep the public screen class name so existing navigation keeps working.
2. Put pure game rules in a separate Dart file, with no widgets or network calls. Use Tic-Tac-Toe's engine as an example.
3. Reuse `GameScaffold(game: gameById('memory'), onRestart: ..., child: ...)` for the common back/help/restart controls. Its content scrolls and is limited to 720px wide; use non-scrolling, shrink-wrapped grids inside it.
4. Use the shared theme and your game's catalog color. Provide clear turns, instructions, completion messages, and a restart flow. Confirm before discarding an unfinished round when practical.
5. To save results, accept `ArcadeController controller` in your screen constructor and pass it from your case in `lib/games/game_registry.dart`.
6. Generate one ID at the **start** of a round and reuse it when reporting completion. Generate a new ID only on restart. Call:

```dart
await controller.recordResult(GameResult(
  id: roundId, // const Uuid().v4() at round start
  gameId: 'memory',
  outcome: 'completed',
  mode: 'solo',
  completedAt: DateTime.now(),
));
```

Allowed modes: `solo`, `local`, `online`. Allowed outcomes: `completed`, `win`, `loss`, `draw`. Same-device rounds use `completed` or `draw`, since the guest is not assigned a side. Online results belong to the database functions; do not create them from the client.

7. Add rule tests under `test/games/your_game/` and at least one widget flow test. Include a win/completion, illegal action, and reset.
8. Once playable and tested, set `ready: true` for your game in `lib/core/game_definition.dart`. Ask the framework owner to merge this small shared-file change if multiple people finish together.

## Expectations by game

- **Chess:** legal piece movement, blocked paths, turn order, check/checkmate, and clear treatment of castling, en passant, promotion, and stalemate. Agree on any simplification before demo day; do not silently allow illegal moves.
- **Checkers:** choose and explain a rules variant, captures, mandatory jumps if required by that variant, kinging, and no-legal-move ending.
- **Sudoku:** at least one valid puzzle with a known solution, fixed clues, tap number entry, conflict feedback, and completion.
- **Word Search:** a solvable grid, visible word list, selection in supported directions, duplicate selection protection, and completion.
- **Memory:** shuffled pairs, two-card reveal, delayed mismatch hiding, input locking during that delay, move count, completion, and cleanup of timers on exit.
- **Tic-Tac-Toe:** preserve the tested rule engine and server protocol; polish animations or instructions and run the two-device demo.

## Run and review

```sh
flutter pub get
flutter run -d chrome
dart format lib test
flutter analyze
flutter test --coverage
```

Use Flutter 3.47.2 / Dart 3.13.2 to match this repository and CI. Supabase is optional for developing solo/local games. Never commit `config/supabase.local.json`.

Create a branch such as `codex/memory-game`, commit meaningful milestones, and open a pull request into `main`. Avoid changing other games or generated platform files unnecessarily. Link the PR to your public-board task and include what you tested. Do not commit merely to inflate the commit count.
