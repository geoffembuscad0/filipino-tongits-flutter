import 'card.dart';

// NOT sealed - DealtCard in deal_cards.dart needs to extend this
abstract class GameEvent {
  const GameEvent();
}

class DrewFromStock extends GameEvent {
  final int playerIndex;
  final PlayingCard card;
  const DrewFromStock(this.playerIndex, this.card);
}

class DrewFromDiscard extends GameEvent {
  final int playerIndex;
  final List<PlayingCard> meldCards;
  const DrewFromDiscard(this.playerIndex, this.meldCards);
}

class ExposedMeld extends GameEvent {
  final int playerIndex;
  final List<PlayingCard> cards;
  const ExposedMeld(this.playerIndex, this.cards);
}

class LaidOff extends GameEvent {
  final int playerIndex;
  final PlayingCard card;
  final int ownerIndex;
  final int meldIndex;
  final List<PlayingCard> meldCardsAfter;
  const LaidOff(
    this.playerIndex,
    this.card,
    this.ownerIndex,
    this.meldIndex,
    this.meldCardsAfter,
  );
}

class Discarded extends GameEvent {
  final int playerIndex;
  final PlayingCard card;
  const Discarded(this.playerIndex, this.card);
}

// Your UI expects this name, not DrawCalled
class CalledDraw extends GameEvent {
  final int playerIndex;
  const CalledDraw(this.playerIndex);
}

// Keep both names - test uses one, UI uses the other
class ChallengeAnswered extends GameEvent {
  final int playerIndex;
  final bool fight;
  const ChallengeAnswered(this.playerIndex, this.fight);
}

class ChallengeResponseRecorded extends GameEvent {
  final int playerIndex;
  final bool fight;
  const ChallengeResponseRecorded(this.playerIndex, this.fight);
}

class RoundFinished extends GameEvent {
  final int? winnerIndex;
  const RoundFinished(this.winnerIndex);
}