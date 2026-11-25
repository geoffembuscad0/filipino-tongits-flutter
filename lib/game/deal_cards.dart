import 'dart:math';

import 'card.dart';
import 'game_state.dart';

GameState dealNewGame({
  required List<PlayerState> players,
  required int firstPlayerIndex,
  Random? random,
}) {
  if (players.length != 3) {
    throw ArgumentError('Tongits setup expects one human and two CPUs.');
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

  // Deal 12 cards to each player, one at a time.
  for (var cardNumber = 0; cardNumber < 12; cardNumber++) {
    for (final player in players) {
      player.hand.add(deck.removeLast());
    }
  }

  // 52 cards - 36 dealt = 16 cards remaining in the stock.
  return GameState(
    players: players,
    stock: deck,
    random: gameRandom,
    currentPlayerIndex: firstPlayerIndex,
  );
}
