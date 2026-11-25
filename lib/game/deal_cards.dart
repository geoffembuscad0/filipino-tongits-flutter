import 'dart:math';

import 'card.dart';
import 'game_event.dart';
import 'game_state.dart';

class DealtCard extends GameEvent {
  final int playerIndex;
  final PlayingCard card;
  const DealtCard(this.playerIndex, this.card);
}

List<PlayerState> createDefaultPlayers() {
  return [
    PlayerState(name: 'You', isCpu: false),
    PlayerState(name: 'CPU 1', isCpu: true),
    PlayerState(name: 'CPU 2', isCpu: true),
  ];
}

List<PlayerState> createCpuDemoPlayers() {
  return [
    PlayerState(name: 'CPU 1', isCpu: true),
    PlayerState(name: 'CPU 2', isCpu: true),
    PlayerState(name: 'CPU 3', isCpu: true),
  ];
}

GameState dealNewGame(List<PlayerState> players, {Random? random}) {
  final rng = random ?? Random();

  // 1. Build 52-card deck: id 0-51
  // rank = (id % 13) + 1, suit = id ~/ 13 in your PlayingCard
  final deck = List<PlayingCard>.generate(52, (i) => PlayingCard(id: i));
  deck.shuffle(rng);

  // 2. Deal: dealer (player 0) gets 13, others get 12
  // Tongits rule
  var deckIndex = 0;
  final dealtEvents = <DealtCard>[];

  for (var playerIndex = 0; playerIndex < players.length; playerIndex++) {
    final count = playerIndex == 0 ? 13 : 12;
    for (var i = 0; i < count; i++) {
      final card = deck[deckIndex++];
      players[playerIndex].hand.add(card);
      dealtEvents.add(DealtCard(playerIndex, card));
    }
  }

  // 3. Rest goes to stock
  final stock = deck.sublist(deckIndex);

  // 4. Create state
  final game = GameState(
    players: players,
    stock: stock,
    random: rng,
  );

  // 5. Emit dealt events
  game.events.addAll(dealtEvents);

  return game;
}