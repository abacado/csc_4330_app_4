# Pocket Arcade

A retro Flutter game hub for CSC 4330: Chess, Checkers, Sudoku, Word Search, Tic-Tac-Toe, and Memory.

## Current framework

- Responsive arcade library with category filters, guest name, and activity journal.
- Shared theme, navigation, instructions, restart controls, and independent game folders.
- Playable Tic-Tac-Toe reference with local two-player rules and Supabase room integration.
- Five explicitly labeled starter screens for teammates to implement, including Memory.
- Optional Supabase anonymous guests, private rooms, and saved results; local play works without configuration.
- Automated analysis, tests, readable reports, coverage, database checks, web build, and Android APK.

This is a framework and integration reference, not six completed games. Online code must be connected and verified against your Supabase project before the demo.

## Run locally

Use Flutter **3.47.2** / Dart **3.13.2**, matching the starter repository and CI.

```sh
flutter pub get
flutter run -d chrome
```

For Android, start an emulator or connect a device and use `flutter run`. Web and Android are the initial verification targets. iOS/macOS require a Mac; other desktop targets retain their Flutter scaffolding but have not been device-tested.

## Team documents

- [Teammate integration guide](docs/TEAM_GUIDE.md)
- [Supabase setup and two-device verification](docs/SUPABASE_SETUP.md)
- [Public task-board backlog](docs/TASK_BOARD.md)
- [Demo and submission checklist](docs/DEMO_CHECKLIST.md)

## Structure

```text
lib/
  core/           Game catalog, result contract, shared controller
  games/          One folder per game + central screen registry
  screens/        Arcade library, activity, guest profile
  services/       Local persistence and optional cloud integration
  theme/          Shared retro palette and control styles
  widgets/        Common game screen and starter screen
supabase/         Database setup and access/rule tests
config/           Example configuration; local values ignored
```

## Check your work

```sh
dart format lib test
flutter analyze
flutter test --coverage
flutter build web
```

On every push and pull request, GitHub Actions shows a readable per-test summary and attaches JUnit, raw test events, coverage, and database output. Successful builds also attach the web app and release APK. Optional GitHub repository variables enable Supabase in those builds; see the setup guide.

Use meaningful commits and a public task board. The prepared task backlog must still be turned into a public GitHub Project by the team.
