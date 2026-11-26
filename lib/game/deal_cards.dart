import 'dart:math';

import 'card.dart';
import 'game_state.dart';

const int cardsPerPlayer = 12;

List<PlayerState> createDefaultPlayers() => [
  PlayerState(name: 'You', isCpu: false),
  PlayerState(name: 'CPU Player 1', isCpu: true),
  PlayerState(name: 'CPU Player 2', isCpu: true),
];

/// Shuffles and deals a new three-player game.
///
/// Cards are dealt one at a time, starting with [firstPlayerIndex] and
/// continuing in player order. The first player (the dealer) then receives a
/// 13th card and opens the round in the discard phase: no draw, only optional
/// melds followed by a discard.
GameState dealNewGame({
  required List<PlayerState> players,
  required int firstPlayerIndex,
  Random? random,
}) {
  if (players.length != 3) {
    throw ArgumentError('Tongits setup expects one human and two CPUs.');
  }
  if (firstPlayerIndex < 0 || firstPlayerIndex >= players.length) {
    throw ArgumentError.value(firstPlayerIndex, 'firstPlayerIndex');
  }
  if (players.any(
    (player) => player.hand.isNotEmpty || player.melds.isNotEmpty,
  )) {
    throw ArgumentError(
      'Players must have empty hands and melds before dealing.',
    );
  }

  final gameRandom = random ?? Random();
  final deck = List<CardId>.generate(52, (id) => id)..shuffle(gameRandom);

  for (var cardNumber = 0; cardNumber < cardsPerPlayer; cardNumber++) {
    for (var offset = 0; offset < players.length; offset++) {
      final playerIndex = (firstPlayerIndex + offset) % players.length;
      players[playerIndex].hand.add(deck.removeLast());
    }
  }

  // The dealer starts with 13 cards and discards first.
  players[firstPlayerIndex].hand.add(deck.removeLast());

  return GameState(
    players: players,
    stock: deck,
    random: gameRandom,
    currentPlayerIndex: firstPlayerIndex,
    startPhase: TurnPhase.discard,
  );
}