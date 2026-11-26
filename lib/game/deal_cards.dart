import 'dart:math';

import 'card.dart';
import 'game_event.dart';
import 'game_state.dart';

class DealtCard extends GameEvent {
  final int playerIndex;
  final CardId card;

  const DealtCard(this.playerIndex, this.card);
}

List<PlayerState> createDefaultPlayers() {
  return [
    PlayerState(name: 'You', isCpu: false),
    PlayerState(name: 'CPU Player 1', isCpu: true),
    PlayerState(name: 'CPU Player 2', isCpu: true),
  ];
}

List<PlayerState> createCpuDemoPlayers() {
  return [
    PlayerState(name: 'CPU Player 1', isCpu: true),
    PlayerState(name: 'CPU Player 2', isCpu: true),
    PlayerState(name: 'CPU Player 3', isCpu: true),
  ];
}

/// Deals 13 cards to the dealer and 12 cards to each other participant.
///
/// [firstPlayerIndex] is retained as the dealer/opening-player index to keep
/// compatibility with the current game setup.
GameState dealNewGame({
  required List<PlayerState> players,
  required int firstPlayerIndex,
  Random? random,
}) {
  if (players.length != 3) {
    throw ArgumentError('Exactly three players are required.');
  }
  if (firstPlayerIndex < 0 || firstPlayerIndex >= players.length) {
    throw ArgumentError.value(
      firstPlayerIndex,
      'firstPlayerIndex',
      'Must be between 0 and ${players.length - 1}',
    );
  }

  final rng = random ?? Random();
  final deck = List<CardId>.generate(52, (index) => index)..shuffle(rng);
  final dealtEvents = <DealtCard>[];

  final targetCounts = List<int>.generate(
    players.length,
    (index) => index == firstPlayerIndex ? 13 : 12,
  );

  for (var round = 0; round < 13; round++) {
    for (var offset = 0; offset < players.length; offset++) {
      final playerIndex = (firstPlayerIndex + offset) % players.length;
      if (round >= targetCounts[playerIndex]) continue;

      final card = deck.removeLast();
      players[playerIndex].hand.add(card);
      dealtEvents.add(DealtCard(playerIndex, card));
    }
  }

  final stock = deck;
  final game = GameState(
    players: players,
    stock: stock,
    random: rng,
    currentPlayerIndex: firstPlayerIndex,
    dealerIndex: firstPlayerIndex,
    phase: TurnPhase.play,
  );

  game.events.addAll(dealtEvents);
  return game;
}

/// Returns the next dealer seat, moving clockwise through player order.
int nextDealerIndex(int currentDealerIndex, {int playerCount = 3}) {
  if (playerCount < 1) {
    throw ArgumentError.value(playerCount, 'playerCount');
  }
  if (currentDealerIndex < 0 || currentDealerIndex >= playerCount) {
    throw ArgumentError.value(currentDealerIndex, 'currentDealerIndex');
  }
  return (currentDealerIndex + 1) % playerCount;
}
