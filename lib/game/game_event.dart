import 'card.dart';

abstract class GameEvent {
  const GameEvent();
  int get playerIndex;
}

class DrewFromStock extends GameEvent {
  final int playerIndex;
  final CardId card;
  const DrewFromStock(this.playerIndex, this.card);
}

class DrewFromDiscard extends GameEvent {
  final int playerIndex;
  final List<CardId> meldCards;
  const DrewFromDiscard(this.playerIndex, this.meldCards);
}

class ExposedMeld extends GameEvent {
  final int playerIndex;
  final List<CardId> cards;
  const ExposedMeld(this.playerIndex, this.cards);
}

class LaidOff extends GameEvent {
  final int playerIndex;
  final CardId card;
  final int ownerIndex;
  final int meldIndex;
  final List<CardId> meldCardsAfter;
  const LaidOff(
    this.playerIndex,
    this.card,
    this.ownerIndex,
    this.meldIndex, [
    this.meldCardsAfter = const [],
  ]);
}

class Discarded extends GameEvent {
  final int playerIndex;
  final CardId card;
  const Discarded(this.playerIndex, this.card);
}

class DrawCalled extends GameEvent {
  final int playerIndex;
  const DrawCalled(this.playerIndex);
}

class CalledDraw extends GameEvent {
  final int playerIndex;
  const CalledDraw(this.playerIndex);
}

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

  @override
  int get playerIndex => winnerIndex ?? -1;
}