import 'card.dart';
import 'game_state.dart';

/// Immutable facts emitted by the rules engine. These events contain no
/// Flame/UI types, so the game rules remain independently testable.
sealed class GameEvent {
  const GameEvent(this.playerIndex);

  final int playerIndex;
}

/// A card dealt from the initial shuffled deck. Used by the table's deal
/// animation; it is not a gameplay draw.
class DealtCard extends GameEvent {
  const DealtCard(super.playerIndex, this.card);

  final CardId card;
}

class DrewFromStock extends GameEvent {
  const DrewFromStock(super.playerIndex, this.card);

  final CardId card;
}

class DrewFromDiscard extends GameEvent {
  DrewFromDiscard(super.playerIndex, List<CardId> cards)
      : meldCards = List<CardId>.unmodifiable(cards);

  final List<CardId> meldCards;
}

class ExposedMeld extends GameEvent {
  ExposedMeld(super.playerIndex, List<CardId> cards)
      : cards = List<CardId>.unmodifiable(cards);

  final List<CardId> cards;
}

class LaidOff extends GameEvent {
  LaidOff(super.playerIndex, this.card, List<CardId> cards)
      : meldCardsAfter = List<CardId>.unmodifiable(cards);

  final CardId card;

  /// Snapshot taken immediately after the lay-off. Do not retain a mutable
  /// [Meld] reference here: later engine actions may mutate that meld before
  /// the table gets to play this event.
  final List<CardId> meldCardsAfter;
}

class Discarded extends GameEvent {
  const Discarded(super.playerIndex, this.card);

  final CardId card;
}

class CalledDraw extends GameEvent {
  const CalledDraw(super.playerIndex);
}

class ChallengeResponseRecorded extends GameEvent {
  const ChallengeResponseRecorded(super.playerIndex, this.fight);

  final bool fight;
}

class RoundFinished extends GameEvent {
  const RoundFinished(super.playerIndex, this.result);

  final RoundResult result;
}
