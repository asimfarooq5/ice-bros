# Ice Bros — Snow Bros (Flutter)

A Flutter take on the classic Snow Bros platformer: walk, jump, freeze enemies
with snow, then kick the resulting snowballs into the rest of the horde to
clear the stage.

## Gameplay

- **Move**: left / right arrow buttons
- **Jump**: up arrow button
- **Shoot snow**: snowflake button — hit an enemy enough times to turn it into
  a rollable snowball
- **Kick**: walk into a snowball to send it rolling; it destroys any enemy it
  touches
- Clear all enemies to win the stage; running out of lives ends the run

## Project layout

- `lib/main.dart` — app entry point
- `lib/game/models.dart` — game data (player, enemies, projectiles, platforms)
- `lib/game/game_controller.dart` — gameplay loop, physics and collision rules
- `lib/game/game_painter.dart` — renders the world with `CustomPainter`
- `lib/game/game_screen.dart` — screen scaffolding, HUD and on-screen controls

## Getting started

```sh
flutter pub get
flutter run
```

## Building

```sh
flutter build apk --release
```

CI workflows for building APKs and publishing GitHub releases live in
`.github/workflows/`.
