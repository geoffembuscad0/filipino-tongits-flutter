import 'dart:math';

import 'card.dart';
import 'game_event.dart';
import 'meld.dart';

export 'game_event.dart';
export 'meld.dart';

/// - draw: the current player must draw (or call Draw).
/// - play: the player may expose melds and lay off cards, then must discard.
///   The opening player starts here, since they do not draw on turn one.
/// - challenge: a Draw was called; the other players choose to fight or fold.
/// - roundOver: see [GameState.result].
enum TurnPhase { draw, play, challenge, roundOver }

enum RoundEndReason { tongits, stockEmpty, drawChallenge, challengeFolded }

class RoundResult {
  const RoundResult({
    required this.winnerIndex,
    required this.reason,
    required this.deadwood,
  });

  /// Null when the round ends in a tie (stock ran out with equal lowest points).
  final int? winnerIndex;
  final RoundEndReason reason;

  /// Unmelded points left in each player's hand, in player order.
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
  final List<GameEvent> events = [];

  List<GameEvent> takeEvents() {
    final pending = List<GameEvent>.unmodifiable(events);
    events.clear();
    return pending;
  }
  GameState({
    required this.players,
    required this.stock,
    required this.random,
    this.currentPlayerIndex = 0,
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

  /// Everything that happened since a UI last cleared this list. The engine
  /// only appends; the table replays the events as animations and clears it.
  // DELETE THIS - this is what broke GameState
  final pending = List<GameEvent>.unmodifiable(events);


  int currentPlayerIndex;
  TurnPhase phase;

  /// Set once the round ends.
  RoundResult? result;

  /// The player who called Draw during the current challenge.
  int? challengerIndex;
  final Map<int, bool> _challengeResponses = {};

  PlayerState get currentPlayer => players[currentPlayerIndex];

  bool get isRoundOver => phase == TurnPhase.roundOver;

  /// Players who still have to answer the current Draw challenge.
  List<int> get pendingChallengeResponders => phase != TurnPhase.challenge
      ? <int>[]
      : [
          for (var i = 0; i < players.length; i++)
            if (i != challengerIndex && !_challengeResponses.containsKey(i)) i,
        ];

  /// Draws the top stock card. If the stock is empty, the round ends instead
  /// and null is returned.
  CardId? drawFromStock() {
    _requirePhase(TurnPhase.draw);

    if (stock.isEmpty) {
      _endByEmptyStock();
      return null;
    }

    final card = stock.removeLast();
    currentPlayer.hand.add(card);
    events.add(DrewFromStock(currentPlayerIndex, card));
    phase = TurnPhase.play;
    return card;
  }

  /// Takes the top discard, which is only allowed when it is immediately
  /// exposed as part of a meld. [meldCards] must contain the discard plus the
  /// cards from the player's hand that complete the meld.
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

    discardPile.removeLast();
    for (final id in fromHand) {
      hand.remove(id);
    }
    currentPlayer.melds.add(Meld(cards: meldCards, kind: kind));
    events.add(DrewFromDiscard(currentPlayerIndex, List<CardId>.of(meldCards)));
    phase = TurnPhase.play;
    _checkOutOfCards();
  }

  /// Exposes a meld from the current player's hand.
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

    for (final id in cards) {
      hand.remove(id);
    }
    currentPlayer.melds.add(Meld(cards: cards, kind: kind));
    events.add(ExposedMeld(currentPlayerIndex, List<CardId>.of(cards)));
    _checkOutOfCards();
  }

  /// Adds [card] from the current player's hand to any exposed [meld].
  void layOff(CardId card, Meld meld) {
    _requirePhase(TurnPhase.play);

    if (!currentPlayer.hand.contains(card)) {
      throw StateError('${currentPlayer.name} does not have card $card.');
    }
    final ownerIndex = players.indexWhere(
      (player) => player.melds.contains(meld),
    );
    if (ownerIndex == -1) {
      throw ArgumentError('That meld is not on the table.');
    }
    if (!canLayOff(meld, card)) {
      throw ArgumentError('Card $card cannot be added to that meld.');
    }

    currentPlayer.hand.remove(card);
    meld.add(card);
    events.add(
      LaidOff(
        currentPlayerIndex,
        card,
        ownerIndex,
        players[ownerIndex].melds.indexOf(meld),
      ),
    );
    _checkOutOfCards();
  }

  void discardFromHand(CardId card) {
    _requirePhase(TurnPhase.play);

    if (!currentPlayer.hand.remove(card)) {
      throw StateError('${currentPlayer.name} does not have card $card.');
    }

    discardPile.add(card);
    events.add(Discarded(currentPlayerIndex, card));

    if (currentPlayer.hand.isEmpty) {
      _finish(currentPlayerIndex, RoundEndReason.tongits);
      return;
    }

    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    phase = TurnPhase.draw;
  }

  /// Calls Draw at the start of a turn. Requires at least one exposed meld.
  void callDraw() {
    _requirePhase(TurnPhase.draw);

    if (currentPlayer.melds.isEmpty) {
      throw StateError('Draw can only be called after exposing a meld.');
    }

    challengerIndex = currentPlayerIndex;
    _challengeResponses.clear();
    events.add(DrawCalled(currentPlayerIndex));
    phase = TurnPhase.challenge;
  }

  /// Records whether [playerIndex] fights or folds. Once everyone has
  /// answered, the lowest deadwood among the caller and the fighters wins.
  /// If the caller and a fighter tie, the caller loses.
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
    events.add(ChallengeAnswered(playerIndex, fight));
    if (pendingChallengeResponders.isEmpty) _resolveChallenge();
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
    // The caller needs strictly fewer points; a tie goes to the fighter.
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
  }

  void _requirePhase(TurnPhase expected) {
    if (phase != expected) {
      throw StateError(
        'Expected phase $expected, but current phase is $phase.',
      );
    }
  }
}