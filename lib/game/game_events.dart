import 'card.dart';

/// Things that happen during a round, in order. The engine appends them to
/// [GameState.events] so a UI can replay a whole CPU turn step by step.
sealed class GameEvent {
  const GameEvent(this.playerIndex);

  final int playerIndex;
}

class DrewFromStock extends GameEvent {
  const DrewFromStock(super.playerIndex, this.card);

  final CardId card;
}

/// The top discard plus the hand cards used to expose a meld with it.
class DrewFromDiscard extends GameEvent {
  const DrewFromDiscard(super.playerIndex, this.meldCards);

  final List<CardId> meldCards;
}

class ExposedMeld extends GameEvent {
  const ExposedMeld(super.playerIndex, this.cards);

  final List<CardId> cards;
}

/// [card] was added to meld number [meldIndex] of player [ownerIndex].
class LaidOff extends GameEvent {
  const LaidOff(super.playerIndex, this.card, this.ownerIndex, this.meldIndex);

  final CardId card;
  final int ownerIndex;
  final int meldIndex;
}

class Discarded extends GameEvent {
  const Discarded(super.playerIndex, this.card);

  final CardId card;
}

class DrawCalled extends GameEvent {
  const DrawCalled(super.playerIndex);
}

class ChallengeAnswered extends GameEvent {
  const ChallengeAnswered(super.playerIndex, this.fight);

  final bool fight;
}