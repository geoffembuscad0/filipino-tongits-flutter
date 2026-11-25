# Tongits animation steps 1–3

These files are intended for the repository's current package structure.

## Included
- `lib/game/game_event.dart`: immutable engine event types.
- `lib/game/game_state.dart`: event recording for draws, melds, lay-offs,
  discards, Draw challenges, and round completion.
- `lib/game/deal_cards.dart`: emits ordered `DealtCard` events and adds
  `createCpuDemoPlayers()`.
- `lib/components/card_component.dart`: one persistent Flame component per
  card, with movement effects and face-up/back rendering.
- `lib/components/tongits_table.dart`: portrait-first CPU turn playback.
- `lib/screens/cpu_vs_cpu_demo_screen.dart`: standalone demo screen.
- `test/game_event_test.dart`: initial event-log tests.

## Add a route from the existing home screen

In `lib/main.dart`, add:

```dart
import 'package:flutter_tongits_offline/screens/cpu_vs_cpu_demo_screen.dart';
```

Then add a button alongside PLAY and HOW TO PLAY:

```dart
OutlinedButton.icon(
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CpuVsCpuDemoScreen(),
      ),
    );
  },
  icon: const Icon(Icons.animation),
  label: const Text('WATCH CPU DEMO'),
),
```

The app already depends on Flame, so no new package is required.

## Important implementation notes

1. `LaidOff` stores a snapshot of the meld's cards after the lay-off. It does
   not store a mutable `Meld` reference; otherwise a later engine action could
   change the event before playback reaches it.
2. The engine is authoritative. `TongitsTable` keeps separate visual zone
   lists because the engine's hands and melds already contain the final state
   by the time a CPU turn is animated.
3. `GameState.takeEvents()` copies and clears the pending queue. This prevents
   the renderer from iterating a list that the engine may append to.
4. The CPU demo uses three CPU players, so the current human-turn interaction
   is not needed yet.
5. Table cards are drawn as backs while in hands. Exposed melds and discards
   turn face-up.
6. The demo is portrait locked while its route is active.

## Review before merging

The repository connection is read-only, so these are prepared as local source
files rather than committed changes. The code has not been run through
`flutter analyze` or `flutter test` in this environment. In particular, test
the Flame effect timing and resize behavior on a device before treating this
as production-ready.
