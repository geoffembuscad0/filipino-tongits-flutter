import 'dart:math';

import 'card.dart';
import 'meld.dart';
import 'game_event.dart';

export 'meld.dart';

enum TurnPhase { draw, play, challenge, roundOver }

enum RoundEndReason { tongits, stockEmpty, drawChallenge, challengeFolded }

class RoundResult {
  const RoundResult({
    required this.winnerIndex,
    required this.reason,
    required this.deadwood,
  });

  final int? winnerIndex;
  final RoundEndReason reason;
  final List<int> deadwood;
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
    this.phase = TurnPhase.draw,
  }) {
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

  /// Ordered, immutable descriptions of actions already resolved by the
  /// engine. A renderer may copy and clear this list, then animate the copy.
  final List<GameEvent> events = [];

  int currentPlayerIndex;
  TurnPhase phase;
  RoundResult? result;
  int? challengerIndex;
  final Map<int, bool> _challengeResponses = {};

  PlayerState get currentPlayer => players[currentPlayerIndex];
  bool get isRoundOver => phase == TurnPhase.roundOver;

  List<int> get pendingChallengeResponders => phase != TurnPhase.challenge
      ? <int>[]
      : [
          for (var i = 0; i < players.length; i++)
            if (i != challengerIndex && !_challengeResponses.containsKey(i)) i,
        ];

  /// Copies and clears the event queue. The returned list is safe to animate
  /// while subsequent engine actions append new events.
  List<GameEvent> takeEvents() {
    final pending = List<GameEvent>.unmodifiable(events);
    events.clear();
    return pending;
  }

  CardId? drawFromStock() {
    _requirePhase(TurnPhase.draw);

    if (stock.isEmpty) {
      _endByEmptyStock();
      return null;
    }

    final playerIndex = currentPlayerIndex;
    final card = stock.removeLast();
    currentPlayer.hand.add(card);
    events.add(DrewFromStock(playerIndex, card));
    phase = TurnPhase.play;
    return card;
  }

  void drawFromDiscard(List<CardId> meldCards) {
    _requirePhase(TurnPhase.draw);

    if (discardPile.isEmpty) {
      throw StateError('There is no card in the discard pile.');
    }

    final top = discardPile.last;
    if (!meldCards.contains(top)) {
      throw ArgumentError('The meld must include the top discard.');
    }

    final kind = classifyMeld(meldCards);
    if (kind == null) {
      throw ArgumentError('Those cards do not form a valid meld.');
    }

    final fromHand = meldCards.where((id) => id != top).toList();
    final hand = currentPlayer.hand;
    if (!fromHand.every(hand.contains)) {
      throw ArgumentError('${currentPlayer.name} does not hold those cards.');
    }

    final playerIndex = currentPlayerIndex;
    discardPile.removeLast();
    for (final id in fromHand) {
      hand.remove(id);
    }
    currentPlayer.melds.add(Meld(cards: meldCards, kind: kind));
    events.add(DrewFromDiscard(playerIndex, meldCards));
    phase = TurnPhase.play;
    _checkOutOfCards();
  }

  void exposeMeld(List<CardId> cards) {
    _requirePhase(TurnPhase.play);

    final kind = classifyMeld(cards);
    if (kind == null) {
      throw ArgumentError('Those cards do not form a valid meld.');
    }

    final hand = currentPlayer.hand;
    if (!cards.every(hand.contains)) {
      throw ArgumentError('${currentPlayer.name} does not hold those cards.');
    }

    final playerIndex = currentPlayerIndex;
    for (final id in cards) {
      hand.remove(id);
    }
    currentPlayer.melds.add(Meld(cards: cards, kind: kind));
    events.add(ExposedMeld(playerIndex, cards));
    _checkOutOfCards();
  }

  void layOff(CardId card, Meld meld) {
    _requirePhase(TurnPhase.play);

    if (!currentPlayer.hand.contains(card)) {
      throw StateError('${currentPlayer.name} does not have card $card.');
    }
    if (!players.any((player) => player.melds.contains(meld))) {
      throw ArgumentError('That meld is not on the table.');
    }
    if (!canLayOff(meld, card)) {
      throw ArgumentError('Card $card cannot be added to that meld.');
    }

    final playerIndex = currentPlayerIndex;
    currentPlayer.hand.remove(card);
    meld.add(card);
    events.add(LaidOff(playerIndex, card, meld.cards));
    _checkOutOfCards();
  }

  void discardFromHand(CardId card) {
    _requirePhase(TurnPhase.play);

    final playerIndex = currentPlayerIndex;
    if (!currentPlayer.hand.remove(card)) {
      throw StateError('${currentPlayer.name} does not have card $card.');
    }

    discardPile.add(card);
    events.add(Discarded(playerIndex, card));

    if (currentPlayer.hand.isEmpty) {
      _finish(currentPlayerIndex, RoundEndReason.tongits);
      return;
    }

    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    phase = TurnPhase.draw;
  }

  void callDraw() {
    _requirePhase(TurnPhase.draw);

    if (currentPlayer.melds.isEmpty) {
      throw StateError('Draw can only be called after exposing a meld.');
    }

    events.add(CalledDraw(currentPlayerIndex));
    challengerIndex = currentPlayerIndex;
    _challengeResponses.clear();
    phase = TurnPhase.challenge;
  }

  void respondToChallenge(int playerIndex, {required bool fight}) {
    _requirePhase(TurnPhase.challenge);

    if (playerIndex < 0 ||
        playerIndex >= players.length ||
        playerIndex == challengerIndex) {
      throw ArgumentError.value(playerIndex, 'playerIndex');
    }
    if (_challengeResponses.containsKey(playerIndex)) {
      throw StateError('${players[playerIndex].name} already responded.');
    }

    _challengeResponses[playerIndex] = fight;
    events.add(ChallengeResponseRecorded(playerIndex, fight));
    if (pendingChallengeResponders.isEmpty) _resolveChallenge();
  }

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

  void _resolveChallenge() {
    final caller = challengerIndex!;
    final fighters = [
      for (final entry in _challengeResponses.entries)
        if (entry.value) entry.key,
    ]..sort();

    if (fighters.isEmpty) {
      _finish(caller, RoundEndReason.challengeFolded);
      return;
    }

    int deadwoodOf(int index) => deadwoodTotal(players[index].hand);

    var winner = fighters.first;
    for (final index in fighters.skip(1)) {
      if (deadwoodOf(index) < deadwoodOf(winner)) winner = index;
    }
    if (deadwoodOf(caller) < deadwoodOf(winner)) winner = caller;

    _finish(winner, RoundEndReason.drawChallenge);
  }

  void _endByEmptyStock() {
    final values = [for (final p in players) deadwoodTotal(p.hand)];
    final lowest = values.reduce(min);
    final leaders = [
      for (var i = 0; i < values.length; i++)
        if (values[i] == lowest) i,
    ];

    _finish(
      leaders.length == 1 ? leaders.first : null,
      RoundEndReason.stockEmpty,
    );
  }

  void _checkOutOfCards() {
    if (currentPlayer.hand.isEmpty) {
      _finish(currentPlayerIndex, RoundEndReason.tongits);
    }
  }

  void _finish(int? winnerIndex, RoundEndReason reason) {
    result = RoundResult(
      winnerIndex: winnerIndex,
      reason: reason,
      deadwood: [for (final p in players) deadwoodTotal(p.hand)],
    );
    phase = TurnPhase.roundOver;
    events.add(RoundFinished(winnerIndex ?? currentPlayerIndex, result!));
  }

  void _requirePhase(TurnPhase expected) {
    if (phase != expected) {
      throw StateError(
        'Expected phase $expected, but current phase is $phase.',
      );
    }
  }
}
