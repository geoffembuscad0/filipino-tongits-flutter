import 'dart:math';

import 'package:flutter_tongits_offline/game/card.dart';
import 'package:flutter_tongits_offline/game/game_event.dart';
import 'package:flutter_tongits_offline/game/game_state.dart';
import 'package:flutter_tongits_offline/game/deal_cards.dart';
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

GameState dealNewGame({
  required List<PlayerState> players,
  required int firstPlayerIndex,
  Random? random,
}) {
  // NEW: reject invalid index
  if (firstPlayerIndex < 0 || firstPlayerIndex >= players.length) {
    throw ArgumentError.value(
      firstPlayerIndex,
      'firstPlayerIndex',
      'Must be between 0 and ${players.length - 1}',
    );
  }

  final rng = random ?? Random();
  final deck = List<CardId>.generate(52, (i) => i);
  deck.shuffle(rng);

  var deckIndex = 0;
  final dealtEvents = <DealtCard>[];

  // NEW: round-robin dealing, one card at a time
  // Dealer (firstPlayerIndex) gets 13, others get 12
  final targetCounts = List<int>.generate(
    players.length,
    (i) => i == firstPlayerIndex ? 13 : 12,
  );

  // 13 rounds max, skip players who are already full
  for (var round = 0; round < 13; round++) {
    for (var offset = 0; offset < players.length; offset++) {
      final playerIndex = (firstPlayerIndex + offset) % players.length;
      if (round >= targetCounts[playerIndex]) continue;

      final card = deck[deckIndex++];
      players[playerIndex].hand.add(card);
      dealtEvents.add(DealtCard(playerIndex, card));
    }
  }

  final stock = deck.sublist(deckIndex);

  final game = GameState(
    players: players,
    stock: stock,
    random: rng,
    currentPlayerIndex: firstPlayerIndex,
    phase: TurnPhase.play,
  );
  game.phase = TurnPhase.play;

  game.events.addAll(dealtEvents);
  return game;
}
