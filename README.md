# Pocket Arcade

Six classic games in one retro arcade, built with Flutter for CSC 4330. Play a quick solo puzzle, share a board with a friend, or challenge someone online without creating an account.

**[Play Pocket Arcade](https://abacado.github.io/csc_4330_app_4/)** · **[GitHub repository](https://github.com/abacado/csc_4330_app_4)**

## Games

All six games are implemented and available from the arcade library.

| Game | Modes | Features |
| --- | --- | --- |
| Chess | Same-device two-player, vs. bot, online rooms | Legal moves, castling, en passant, promotion, checkmate and draw detection |
| Checkers | Same-device two-player | Mandatory captures, multiple jumps, kings and win detection |
| Sudoku | Solo | Difficulty selection, pencil notes, conflict highlighting and completion detection |
| Word Search | Solo | Generated puzzles, forward/backward and diagonal word selection |
| Tic-Tac-Toe | Same-device two-player, online rooms | Turn validation, wins, draws and restart |
| Memory | Solo | Shuffled pairs, match tracking, move counter and restart |

The shared app includes a responsive retro theme, game instructions, category filters, a guest name, and an activity journal of completed games. Local play works without Supabase configuration.

## Play online

Open the website on two devices, or use a normal browser window and a private/incognito window. Two ordinary tabs in the same browser share a guest identity.

1. Open **Chess** or **Tic-Tac-Toe** and choose **Play with a room code**.
2. One player selects **Create a room** and shares the six-character code.
3. The other player enters the code and selects **Join room**.
4. The host plays White in Chess or X in Tic-Tac-Toe. Moves normally appear on the other device within about two seconds.

Keep the room screen open during play. Rooms last 24 hours; rejoin using the same browser/device and code. Create a new room for a rematch. Players do not need a Supabase account or the source code.

## Run locally

Use Flutter **3.47.2** / Dart **3.13.2**, matching the automated build.

### Local play

From the project folder:

```sh
flutter pub get
flutter run -d chrome
```

### With online play and cloud results

Copy `config/supabase.example.json` to `config/supabase.local.json` and fill in the shared project's URL and publishable key. The local file is ignored by Git, so teammates need to configure it separately.

```sh
flutter pub get
flutter run -d chrome --dart-define-from-file=config/supabase.local.json
```

In VS Code, open **Run and Debug**, select **Pocket Arcade (Supabase)**, and press **F5**. Select **Pocket Arcade (local only)** for offline configuration. Fully restart after changing configuration; hot reload does not replace compile-time values.

For Android, connect a device or start an emulator, then replace `chrome` with its ID from `flutter devices`. Web and Android are the build targets verified by CI. Other platform folders are included, but are not a claim of device testing.

## Server component

Supabase provides hosted PostgreSQL, anonymous authentication, private game rooms, and saved results. No separate custom server needs to run on a teammate's computer.

The project owner enables anonymous sign-ins and applies `supabase/setup.sql` once to the shared project. Everyone's app connects to that same project. Use only the publishable client key in the app, never a service-role key or database password.

Results save locally first and can sync to the cloud. Row-level security limits access to a guest's own results and rooms. Online rooms poll for updates every two seconds. Tic-Tac-Toe moves are validated by database functions; Chess rules are checked by the Dart engine, while the server enforces room membership and turn order. This is a class-project multiplayer system, not a cheat-proof competitive service.

Guest identities belong to a browser/device. Clearing browser data loses that identity; guest names are not cross-device logins.

See the **[Supabase setup and two-device verification guide](docs/SUPABASE_SETUP.md)** for setup and connection troubleshooting.

## Tests and automated builds

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
```

Tests cover all six games, invalid actions, wins and completion, restarts, saved results, screen layouts, chess bot decisions, and online-room failure/recovery behavior. Separate SQL tests check database access policies and room rules in an isolated PostgreSQL instance.

Verified locally on **October 2, 2026**: **127 passing Flutter tests** and **92.0% reported line coverage** (1,909 of 2,075 lines). Rerun the commands above for current results after further changes.

Coverage is written to `coverage/lcov.info`. It measures executed lines in the files included in the report, not every possible behavior or the live Supabase service. Online widget tests use a simulated backend; complete the two-device checks before the demo.

In **GitHub → Actions → Pocket Arcade CI**, open a run to see its test summary. Download the test-report/coverage and database-report artifacts for details. CI checks formatting, analysis, Flutter tests, database tests, and web/Android builds. The website deploys from `main` only after the app and database jobs succeed.

## Website deployment

The public website is hosted on GitHub Pages. Future successful pushes to `main` update the same URL.

For repository administrators:

1. Under **Settings → Pages**, set **Source** to **GitHub Actions**.
2. Under **Settings → Secrets and variables → Actions → Variables**, add `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`.
3. Push to `main`, or select **Run workflow** on `main` in Actions.
4. Wait for the **pages** job to succeed before checking the website.

For a local Android release build with cloud access:

```sh
flutter build apk --release --dart-define-from-file=config/supabase.local.json
```

## Project layout

```text
lib/
  core/        Game catalog, results and shared controller
  games/       Rules, boards and screens for all six games
  screens/     Arcade library, activity journal and player profile
  services/    Local storage and Supabase integration
  theme/       Shared retro styling
  widgets/     Shared game layout and controls
test/          Flutter logic and widget tests
supabase/      Database schema, functions and SQL tests
config/        Example connection configuration
.github/       Automated build and deployment workflow
```

## Team resources

- [Teammate integration guide](docs/TEAM_GUIDE.md)
- [Supabase setup and multiplayer verification](docs/SUPABASE_SETUP.md)
- [Task-board planning reference](docs/TASK_BOARD.md)
- [Demo and submission checklist](docs/DEMO_CHECKLIST.md)

The task-board planning document is a reference, not the public Trello board. Include the team's actual public board URL with the final submission.
