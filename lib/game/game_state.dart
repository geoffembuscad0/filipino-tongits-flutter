import 'dart:math';

import 'card.dart';

enum TurnPhase { draw, discard, roundOver }

enum MeldKind { set, run }

class Meld {
  Meld({required this.cards, required this.kind});

  final List<CardId> cards;
  final MeldKind kind;
}

class PlayerState {
  PlayerState({required this.name, required this.isCpu});

  final String name;
  final bool isCpu;
  final List<CardId> hand = [];
  final List<Meld> melds = [];
}

class GameState {
  GameState({
    required this.players,
    required this.stock,
    required this.random,
    required this.currentPlayerIndex,
  }) : phase = TurnPhase.draw {
    if (players.length != 3) {
      throw ArgumentError('This game setup expects exactly three players.');
    }
    if (currentPlayerIndex < 0 || currentPlayerIndex >= players.length) {
      throw ArgumentError.value(currentPlayerIndex, 'currentPlayerIndex');
    }
  }

  final List<PlayerState> players;
  final List<CardId> stock;
  final List<CardId> discardPile = [];
  final Random random;

  int currentPlayerIndex;
  TurnPhase phase;

  PlayerState get currentPlayer => players[currentPlayerIndex];

  CardId? drawFromStock() {
    _requirePhase(TurnPhase.draw);

    if (stock.isEmpty) {
      phase = TurnPhase.roundOver;
      return null;
    }

    final card = stock.removeLast();
    currentPlayer.hand.add(card);
    phase = TurnPhase.discard;
    return card;
  }

  CardId drawFromDiscard() {
    _requirePhase(TurnPhase.draw);

    if (discardPile.isEmpty) {
      throw StateError('There is no card in the discard pile.');
    }

    final card = discardPile.removeLast();
    currentPlayer.hand.add(card);
    phase = TurnPhase.discard;
    return card;
  }

  void discardFromHand(CardId card) {
    _requirePhase(TurnPhase.discard);

    if (!currentPlayer.hand.remove(card)) {
      throw StateError('${currentPlayer.name} does not have card $card.');
    }

    discardPile.add(card);
    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    phase = TurnPhase.draw;
  }

  /// Useful in tests/debugging to ensure a card hasn't been duplicated
  /// or lost between the deck, hands, discards, and melds.
  bool get hasValidCardConservation {
    final cardsInPlay = <CardId>[
      ...stock,
      ...discardPile,
      for (final player in players) ...player.hand,
      for (final player in players)
        for (final meld in player.melds) ...meld.cards,
    ];

    return cardsInPlay.length == 52 &&
        cardsInPlay.toSet().length == 52 &&
        cardsInPlay.every((id) => id >= 0 && id < 52);
  }

  void _requirePhase(TurnPhase expected) {
    if (phase != expected) {
      throw StateError(
        'Expected phase $expected, but current phase is $phase.',
      );
    }
  }
}
