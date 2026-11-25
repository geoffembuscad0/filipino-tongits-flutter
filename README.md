# Tongits Offline

A small personal project exploring game development with **Flutter** and **Flame**.

The idea is to build an offline Tongits game where you play against CPU opponents. I’m using it as a chance to learn about game logic, card handling, simple AI, and game-style UI—nothing extravagant, just a fun project to work on.

## Current preview

The app currently has a landing screen with a small card preview drawn in Flame. The cards are rendered in code, so the project doesn’t depend on card image assets.

## Planned features

- A local game for one player and two CPU opponents.
- Jack-en-Poy to choose who gets the first turn.
- A standard 52-card deck represented by stable card IDs.
- Player hands, stock, discards, and melds managed in Dart.
- Basic CPU decisions for drawing and discarding.
- A simple card-table interface and animations.

The Tongits rules and CPU strategy are still being explored. Details may change as the project develops.

## Built with

- [Flutter](https://flutter.dev/) for the app and UI.
- [Flame](https://flame-engine.org/) for game-style rendering and possible animations.
- Dart for game state, card handling, and CPU logic.

## Run locally

Make sure Flutter is installed, then run:

```bash
flutter pub get
flutter run
```

To launch in a browser:

```bash
flutter run -d chrome
```

For the web build to be available offline in a browser, it may need to be opened once while online and configured for offline caching. The app itself is designed not to require a game server or an internet connection during play.

## Project status

This is a work in progress and a personal learning project. It is not a finished or officially rules-certified version of Tongits.

## License

No license has been selected yet. For now, this project is shared for personal exploration and discussion.