# Connect Pocket Arcade to Supabase

The app runs locally without configuration. Connect a free Supabase project to enable anonymous guests, saved results, and private Tic-Tac-Toe rooms. No separately hosted server, paid plan, or Realtime toggle is needed.

## One-time project setup

1. Create a project on the Free plan in your Supabase account. Save your database password privately; the app does not use it.
2. Under Authentication settings, enable **Allow anonymous sign-ins**. This is distinct from the public API key named `anon`.
3. Open SQL Editor, paste the entire contents of `supabase/setup.sql`, and run it. You should see `rooms` and `game_results` in Table Editor. The script includes access policies and the three room functions.
4. Find the project URL and **publishable** API key in the project's Connect dialog or API settings. A legacy `anon` key also works. Never put a secret key, service-role key, or database password in the Flutter app.
5. Copy `config/supabase.example.json` to `config/supabase.local.json`. Replace both placeholders with your URL and publishable key. The local file is ignored by Git. These client keys are public by design; row-level security protects data.
6. Run:

```sh
flutter pub get
flutter run -d chrome --dart-define-from-file=config/supabase.local.json
```

For Android, replace `chrome` with the device ID shown by `flutter devices`. Restart the app after changing configuration; hot reload cannot change compile-time values.

The Player tab should show **CLOUD CONNECTED**. If it does not, check anonymous sign-in, both config values, the SQL script, and your internet connection, then tap Reconnect. Ensure the project's Data API is enabled and exposes the `public` schema.

## Verify the actual server component

1. Finish a local Tic-Tac-Toe round. Confirm it appears in Activity and in Supabase's `game_results` table.
2. Restart using the same browser/device and confirm your guest and history remain.
3. Use two separate devices or a normal and private browser window. Two ordinary tabs share a guest identity and are not two players.
4. On player A, open Tic-Tac-Toe → Play with a room code → Create a room.
5. On player B, join with A's code. Host is X; guest is O.
6. Alternate moves. Verify the other player sees changes within roughly two seconds. An occupied square or the other player's turn must not be playable.
7. Finish the match and verify one win and one loss (or two draws) in the respective Activity screens. Tap Sync results if necessary.
8. Turn off a connection briefly. Moves should stop after the connection error and the room should recover when connectivity returns.

Rooms expire after 24 hours. To return to a room, join its code on the original device. Returning home does not forfeit a match. Rematches use a new room code. Expired rows are retained; for this class demo they can be removed manually in the dashboard if needed.

## Build with the connection enabled

```sh
flutter build web --dart-define-from-file=config/supabase.local.json
flutter build apk --release --dart-define-from-file=config/supabase.local.json
```

The repository's GitHub Actions workflow also accepts repository **variables** named `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`. Set both under Settings → Secrets and variables → Actions → Variables. Without them, CI intentionally builds a local-only app. Do not put privileged keys in those variables.

## How it works

- Anonymous Auth supplies a persistent guest ID on each browser/device. Display names are stored only locally.
- Solo and same-device results save locally first and upload on connection or Sync results. Uploads use stable IDs to prevent duplicates. Local results are self-reported, suitable for a personal journal rather than a competitive leaderboard.
- Online boards live in `rooms`. The app polls its current room every two seconds, only while the room screen is open and the app is active.
- Three database functions create rooms, join rooms, and validate moves. Row locks prevent two players from taking the same turn. Server-generated online results cannot be inserted directly by the client.
- Row-level security only lets a guest read their own results and rooms they belong to. Joining an open room requires its code.
- There is no cross-device account recovery. Clearing application/browser data loses the anonymous identity.

## Automated database checks

CI creates an isolated Postgres database, runs `supabase/tests/bootstrap.sql` to simulate Auth, applies `setup.sql`, and runs `rooms_test.sql`. **Do not run bootstrap.sql in your real Supabase project.** This checks database behavior but does not replace the two-device verification above.

References: [Flutter setup](https://supabase.com/docs/reference/dart/installing), [anonymous sign-in](https://supabase.com/docs/guides/auth/auth-anonymous), [free plan](https://supabase.com/pricing).
