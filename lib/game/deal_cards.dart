import 'dart:math';

import 'card.dart';
import 'game_event.dart';
import 'game_state.dart';

const int cardsPerPlayer = 12;

List<PlayerState> createDefaultPlayers() => [
  PlayerState(name: 'You', isCpu: false),
  PlayerState(name: 'CPU Player 1', isCpu: true),
  PlayerState(name: 'CPU Player 2', isCpu: true),
];

/// All-CPU seats used only by the animation/demo screen.
List<PlayerState> createCpuDemoPlayers() => [
  PlayerState(name: 'CPU Player 1', isCpu: true),
  PlayerState(name: 'CPU Player 2', isCpu: true),
  PlayerState(name: 'CPU Player 3', isCpu: true),
];

GameState dealNewGame({
  required List<PlayerState> players,
  required int firstPlayerIndex,
  Random? random,
}) {
  if (players.length != 3) {
    throw ArgumentError('Tongits setup expects exactly three players.');
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
  final dealEvents = <DealtCard>[];

  for (var cardNumber = 0; cardNumber < cardsPerPlayer; cardNumber++) {
    for (var offset = 0; offset < players.length; offset++) {
      final playerIndex = (firstPlayerIndex + offset) % players.length;
      final card = deck.removeLast();
      players[playerIndex].hand.add(card);
      dealEvents.add(DealtCard(playerIndex, card));
    }
  }

  final openingCard = deck.removeLast();
  players[firstPlayerIndex].hand.add(openingCard);
  dealEvents.add(DealtCard(firstPlayerIndex, openingCard));

  final game = GameState(
    players: players,
    stock: deck,
    random: gameRandom,
    currentPlayerIndex: firstPlayerIndex,
    phase: TurnPhase.play,
  );
  game.events.addAll(dealEvents);
  return game;
}
