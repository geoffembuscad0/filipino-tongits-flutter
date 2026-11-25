import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tongits_offline/game/card.dart';
import 'package:flutter_tongits_offline/game/game_state.dart';

int id(Suit suit, int rank) => suit.index * 13 + rank - 1;

GameState gameWith({
  List<CardId> hand0 = const [],
  List<CardId> hand1 = const [],
  List<CardId> hand2 = const [],
  List<CardId> stock = const [],
  TurnPhase phase = TurnPhase.draw,
}) {
  final players = [
    PlayerState(name: 'You', isCpu: false)..hand.addAll(hand0),
    PlayerState(name: 'CPU Player 1', isCpu: true)..hand.addAll(hand1),
    PlayerState(name: 'CPU Player 2', isCpu: true)..hand.addAll(hand2),
  ];
  return GameState(
    players: players,
    stock: List<CardId>.of(stock),
    random: Random(1),
    currentPlayerIndex: 0,
    phase: phase,
  );
}

void main() {
  final c3 = id(Suit.clubs, 3);
  final c4 = id(Suit.clubs, 4);
  final c5 = id(Suit.clubs, 5);
  final c6 = id(Suit.clubs, 6);
  final d9 = id(Suit.diamonds, 9);
  final h12 = id(Suit.hearts, 12);

  test('a stock draw is logged with the card', () {
    final game = gameWith(hand0: [d9], stock: [c3]);

    game.drawFromStock();

    final event = game.events.single as DrewFromStock;
    expect(event.playerIndex, 0);
    expect(event.card, c3);
  });

  test('a turn is logged in order', () {
    final game = gameWith(hand0: [c3, c4, c5, d9, h12], phase: TurnPhase.play);

    game.exposeMeld([c3, c4, c5]);
    game.discardFromHand(d9);

    expect(game.events.map((e) => e.runtimeType).toList(), [
      ExposedMeld,
      Discarded,
    ]);
    expect((game.events.first as ExposedMeld).cards, [c3, c4, c5]);
    expect((game.events.last as Discarded).card, d9);
  });

  test('taking the discard logs the whole meld', () {
    final game = gameWith(hand0: [c3, c4, d9]);
    game.discardPile.add(c5);

    game.drawFromDiscard([c3, c4, c5]);

    final event = game.events.single as DrewFromDiscard;
    expect(event.meldCards, unorderedEquals([c3, c4, c5]));
  });

  test('a layoff records the meld owner and index', () {
    final game = gameWith(hand0: [c6, d9], phase: TurnPhase.play);
    final meld = Meld(cards: [c3, c4, c5], kind: MeldKind.run);
    game.players[1].melds.add(meld);

    game.layOff(c6, meld);

    final event = game.events.single as LaidOff;
    expect(event.playerIndex, 0);
    expect(event.card, c6);
    expect(event.ownerIndex, 1);
    expect(event.meldIndex, 0);
  });

  test('Draw challenges are logged', () {
    final game = gameWith(
      hand0: [id(Suit.clubs, 1)],
      hand1: [id(Suit.spades, 13)],
      hand2: [id(Suit.spades, 12)],
    );
    game.players[0].melds.add(Meld(cards: [c3, c4, c5], kind: MeldKind.run));

    game.callDraw();
    game.respondToChallenge(1, fight: true);
    game.respondToChallenge(2, fight: false);

    expect(game.events.map((e) => e.runtimeType).toList(), [
      DrawCalled,
      ChallengeAnswered,
      ChallengeAnswered,
    ]);
    expect((game.events[1] as ChallengeAnswered).fight, isTrue);
    expect((game.events[2] as ChallengeAnswered).fight, isFalse);
  });
}