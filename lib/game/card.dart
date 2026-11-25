typedef CardId = int;

enum Suit { clubs, diamonds, hearts, spades }

class PlayingCard {
  const PlayingCard(this.id);

  /// IDs 0–12 are clubs, 13–25 diamonds, and so on.
  /// Within each suit: Ace, 2, 3, ... King.
  final CardId id;

  Suit get suit => Suit.values[id ~/ 13];

  /// Ace = 1, numbered cards = 2–10, Jack = 11, Queen = 12, King = 13.
  int get rank => (id % 13) + 1;

  String get rankLabel {
    switch (rank) {
      case 1:
        return 'A';
      case 11:
        return 'J';
      case 12:
        return 'Q';
      case 13:
        return 'K';
      default:
        return '$rank';
    }
  }

  String get suitSymbol {
    switch (suit) {
      case Suit.clubs:
        return '♣';
      case Suit.diamonds:
        return '♦';
      case Suit.hearts:
        return '♥';
      case Suit.spades:
        return '♠';
    }
  }

  /// A basic deadwood value for the CPU heuristic.
  int get deadwoodValue => rank > 10 ? 10 : rank;

  @override
  String toString() => '$rankLabel$suitSymbol';
}
