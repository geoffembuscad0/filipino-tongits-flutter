import 'dart:math';

import 'card.dart';
import 'meld_rules.dart';

export 'meld_rules.dart' show MeldKind;

/// [challenge] is the pause after a player calls Draw, while the other
/// players answer Fight or Fold.
enum TurnPhase { draw, discard, challenge, roundOver }

enum RoundEndReason { tongits, stockEmpty, drawChallenge, challengeFolded }

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
    TurnPhase startPhase = TurnPhase.draw,
  }) : phase = startPhase {
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

  /// Set when the round ends. Null winner with [RoundEndReason.stockEmpty]
  /// means the lowest hands tied (a draw).
  int? winnerIndex;
  RoundEndReason? endReason;

  /// A card taken from the discard pile that must be melded or laid off
  /// before this player may discard.
  CardId? pendingDiscardCard;

  /// Who called Draw (valid during and after a challenge).
  int? challengerIndex;

  /// Fight (true) or Fold (false) answers, keyed by player index.
  final Map<int, bool> challengeResponses = {};

  PlayerState get currentPlayer => players[currentPlayerIndex];

  int handValue(PlayerState player) => player.hand.fold(
    0,
    (sum, id) => sum + PlayingCard(id).deadwoodValue,
  );

  /// The top discard may only be taken if it can be used immediately,
  /// either in a new meld with the hand or laid off on an exposed meld.
  bool get canDrawFromDiscard {
    if (phase != TurnPhase.draw || discardPile.isEmpty) return false;
    final top = discardPile.last;
    if (canFormMeldWith(top, currentPlayer.hand)) return true;
    for (var owner = 0; owner < players.length; owner++) {
      for (var i = 0; i < players[owner].melds.length; i++) {
        if (canLayOff(top, owner, i)) return true;
      }
    }
    return false;
  }

  /// A player may call Draw at the start of their turn (before drawing) once
  /// they have exposed at least one meld.
  bool get canCallDraw =>
      phase == TurnPhase.draw && currentPlayer.melds.isNotEmpty;

  /// Players who still have to answer the current challenge, in turn order
  /// starting after the caller.
  List<int> get pendingChallengeResponders {
    final caller = challengerIndex;
    if (phase != TurnPhase.challenge || caller == null) return const [];

    final pending = <int>[];
    for (var offset = 1; offset < players.length; offset++) {
      final index = (caller + offset) % players.length;
      if (!challengeResponses.containsKey(index)) pending.add(index);
    }
    return pending;
  }

  /// Calls Draw instead of drawing. The other players now answer Fight or Fold.
  void callDraw() {
    _requirePhase(TurnPhase.draw);
    if (!canCallDraw) {
      throw StateError('Expose at least one meld before calling Draw.');
    }

    challengerIndex = currentPlayerIndex;
    challengeResponses.clear();
    phase = TurnPhase.challenge;
  }

  /// Records [playerIndex]'s answer. When everyone has answered, the round
  /// is resolved:
  /// * everyone folds: the caller wins;
  /// * otherwise the lowest hand among the caller and the players who chose
  ///   Fight wins, and folders lose. A tie goes against the caller; if the
  ///   lowest hand is still tied between fighters it is a draw.
  void respondToChallenge(int playerIndex, bool fight) {
    _requirePhase(TurnPhase.challenge);
    if (!pendingChallengeResponders.contains(playerIndex)) {
      throw StateError('Player $playerIndex cannot answer the challenge now.');
    }

    challengeResponses[playerIndex] = fight;
    if (pendingChallengeResponders.isEmpty) _resolveChallenge();
  }

  void _resolveChallenge() {
    final caller = challengerIndex!;
    final fighters = [
      for (final entry in challengeResponses.entries)
        if (entry.value) entry.key,
    ];

    if (fighters.isEmpty) {
      _endRound(caller, RoundEndReason.challengeFolded);
      return;
    }

    final contenders = [caller, ...fighters];
    final lowest = contenders
        .map((index) => handValue(players[index]))
        .reduce(min);
    var winners = [
      for (final index in contenders)
        if (handValue(players[index]) == lowest) index,
    ];

    // Ties go against the player who called Draw.
    if (winners.length > 1) {
      winners = winners.where((index) => index != caller).toList();
    }

    _endRound(
      winners.length == 1 ? winners.single : null,
      RoundEndReason.drawChallenge,
    );
  }

  CardId? drawFromStock() {
    _requirePhase(TurnPhase.draw);

    if (stock.isEmpty) {
      _endByStockEmpty();
      return null;
    }

    final card = stock.removeLast();
    currentPlayer.hand.add(card);
    phase = TurnPhase.discard;
    return card;
  }

  CardId drawFromDiscard() {
    _requirePhase(TurnPhase.draw);

    if (!canDrawFromDiscard) {
      throw StateError('The top discard cannot be used in a meld right now.');
    }

    final card = discardPile.removeLast();
    currentPlayer.hand.add(card);
    pendingDiscardCard = card;
    phase = TurnPhase.discard;
    return card;
  }

  /// Exposes a new set or run from the current player's hand.
  Meld layMeld(List<CardId> cards) {
    _requirePhase(TurnPhase.discard);

    final kind = classifyMeld(cards);
    if (kind == null) {
      throw ArgumentError('Not a valid set or run: $cards');
    }

    final hand = currentPlayer.hand;
    if (!cards.every(hand.contains)) {
      throw StateError('${currentPlayer.name} does not hold all of $cards.');
    }

    hand.removeWhere(cards.contains);
    final meld = Meld(cards: List<CardId>.of(cards), kind: kind);
    sortMeldCards(meld.cards, kind);
    currentPlayer.melds.add(meld);

    if (pendingDiscardCard != null && cards.contains(pendingDiscardCard)) {
      pendingDiscardCard = null;
    }
    if (hand.isEmpty) _endRound(currentPlayerIndex, RoundEndReason.tongits);
    return meld;
  }

  bool canLayOff(CardId card, int ownerIndex, int meldIndex) {
    final meld = players[ownerIndex].melds[meldIndex];
    return classifyMeld([...meld.cards, card]) != null;
  }

  /// Adds [card] to an exposed meld (sapaw / layoff), yours or an opponent's.
  void layOff(CardId card, int ownerIndex, int meldIndex) {
    _requirePhase(TurnPhase.discard);

    final hand = currentPlayer.hand;
    if (!hand.contains(card)) {
      throw StateError('${currentPlayer.name} does not have card $card.');
    }
    if (!canLayOff(card, ownerIndex, meldIndex)) {
      throw ArgumentError('Card $card does not extend that meld.');
    }

    final meld = players[ownerIndex].melds[meldIndex];
    hand.remove(card);
    meld.cards.add(card);
    sortMeldCards(meld.cards, meld.kind);

    if (pendingDiscardCard == card) pendingDiscardCard = null;
    if (hand.isEmpty) _endRound(currentPlayerIndex, RoundEndReason.tongits);
  }

  void discardFromHand(CardId card) {
    _requirePhase(TurnPhase.discard);

    if (pendingDiscardCard != null) {
      throw StateError('Meld or lay off the card taken from the discard first.');
    }
    if (!currentPlayer.hand.remove(card)) {
      throw StateError('${currentPlayer.name} does not have card $card.');
    }

    discardPile.add(card);

    if (currentPlayer.hand.isEmpty) {
      _endRound(currentPlayerIndex, RoundEndReason.tongits);
      return;
    }

    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    phase = TurnPhase.draw;

    // Stock exhausted: if the next player has nothing to draw (and can't use
    // the discard), the round ends now with a showdown instead of waiting
    // for a stock tap that can never happen.
    if (stock.isEmpty && !canDrawFromDiscard) _endByStockEmpty();
  }

  /// Last-resort recovery that always ends the current turn: draws from the
  /// stock if needed, drops any pending discard-pile requirement and discards
  /// the last card. Only used when normal CPU logic fails.
  void forceEndTurn() {
    if (phase == TurnPhase.roundOver) return;

    if (phase == TurnPhase.challenge) {
      // Anyone who still hasn't answered folds.
      for (final index in pendingChallengeResponders.toList()) {
        respondToChallenge(index, false);
      }
      return;
    }

    if (phase == TurnPhase.draw) {
      if (stock.isEmpty) {
        _endByStockEmpty();
        return;
      }
      currentPlayer.hand.add(stock.removeLast());
      phase = TurnPhase.discard;
    }

    pendingDiscardCard = null;
    final hand = currentPlayer.hand;
    if (hand.isEmpty) {
      _endRound(currentPlayerIndex, RoundEndReason.tongits);
      return;
    }
    discardFromHand(hand.last);
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

  void _endRound(int? winner, RoundEndReason reason) {
    phase = TurnPhase.roundOver;
    pendingDiscardCard = null;
    winnerIndex = winner;
    endReason = reason;
  }

  /// Stock ran out: the lowest hand wins; equal lowest hands are a draw.
  void _endByStockEmpty() {
    final values = [for (final player in players) handValue(player)];
    final lowest = values.reduce(min);
    final lowestPlayers = [
      for (var i = 0; i < values.length; i++)
        if (values[i] == lowest) i,
    ];
    _endRound(
      lowestPlayers.length == 1 ? lowestPlayers.first : null,
      RoundEndReason.stockEmpty,
    );
  }

  void _requirePhase(TurnPhase expected) {
    if (phase != expected) {
      throw StateError(
        'Expected phase $expected, but current phase is $phase.',
      );
    }
  }
}