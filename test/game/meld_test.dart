import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tongits_offline/game/card.dart';
import 'package:flutter_tongits_offline/game/meld.dart';

/// Clubs 0–12, diamonds 13–25, hearts 26–38, spades 39–51.
int id(Suit suit, int rank) => suit.index * 13 + rank - 1;

void main() {
  group('classifyMeld', () {
    test('recognizes sets of three and four', () {
      expect(
        classifyMeld([
          id(Suit.clubs, 7),
          id(Suit.diamonds, 7),
          id(Suit.hearts, 7),
        ]),
        MeldKind.set,
      );
      expect(
        classifyMeld([for (final s in Suit.values) id(s, 12)]),
        MeldKind.set,
      );
    });

    test('recognizes runs, with the Ace low only', () {
      expect(
        classifyMeld([id(Suit.clubs, 1), id(Suit.clubs, 2), id(Suit.clubs, 3)]),
        MeldKind.run,
      );
      expect(
        classifyMeld([
          id(Suit.spades, 10),
          id(Suit.spades, 11),
          id(Suit.spades, 12),
          id(Suit.spades, 13),
        ]),
        MeldKind.run,
      );
      expect(
        classifyMeld([
          id(Suit.clubs, 12),
          id(Suit.clubs, 13),
          id(Suit.clubs, 1),
        ]),
        isNull,
      );
    });

    test('rejects invalid groups', () {
      expect(classifyMeld([id(Suit.clubs, 3), id(Suit.clubs, 4)]), isNull);
      expect(
        classifyMeld([
          id(Suit.clubs, 3),
          id(Suit.diamonds, 4),
          id(Suit.clubs, 5),
        ]),
        isNull,
      );
      expect(
        classifyMeld([id(Suit.clubs, 3), id(Suit.clubs, 4), id(Suit.clubs, 6)]),
        isNull,
      );
    });
  });

  group('canLayOff', () {
    test('extends a run at either end only', () {
      final run = Meld(
        cards: [id(Suit.clubs, 3), id(Suit.clubs, 4), id(Suit.clubs, 5)],
        kind: MeldKind.run,
      );
      expect(canLayOff(run, id(Suit.clubs, 6)), isTrue);
      expect(canLayOff(run, id(Suit.clubs, 2)), isTrue);
      expect(canLayOff(run, id(Suit.clubs, 7)), isFalse);
      expect(canLayOff(run, id(Suit.diamonds, 6)), isFalse);
    });

    test('adds a fourth card to a set, but not a fifth', () {
      final set = Meld(
        cards: [id(Suit.clubs, 9), id(Suit.diamonds, 9), id(Suit.hearts, 9)],
        kind: MeldKind.set,
      );
      expect(canLayOff(set, id(Suit.spades, 9)), isTrue);
      expect(canLayOff(set, id(Suit.spades, 8)), isFalse);

      set.add(id(Suit.spades, 9));
      expect(set.cards, hasLength(4));
    });
  });

  group('planMelds', () {
    test('finds a set and a run and leaves the rest as deadwood', () {
      final hand = [
        id(Suit.clubs, 3),
        id(Suit.clubs, 4),
        id(Suit.clubs, 5),
        id(Suit.diamonds, 9),
        id(Suit.hearts, 9),
        id(Suit.spades, 9),
        id(Suit.clubs, 13),
      ];
      final plan = planMelds(hand);

      expect(plan.melds, hasLength(2));
      expect(plan.deadwood, [id(Suit.clubs, 13)]);
      expect(plan.deadwoodValue, 10);
    });

    test('chooses the split that leaves the fewest points', () {
      // Clubs 5-6-7 as a run (leaves 5♦ 5♥ = 10) beats the set of fives
      // (leaves 6♣ 7♣ = 13).
      final hand = [
        id(Suit.clubs, 5),
        id(Suit.clubs, 6),
        id(Suit.clubs, 7),
        id(Suit.diamonds, 5),
        id(Suit.hearts, 5),
      ];
      expect(planMelds(hand).deadwoodValue, 10);
    });
  });

  test('meldsUsingCard only returns melds that include the card', () {
    final hand = [id(Suit.clubs, 3), id(Suit.clubs, 4), id(Suit.hearts, 12)];
    final options = meldsUsingCard(id(Suit.clubs, 5), hand);

    expect(options, hasLength(1));
    expect(options.first, contains(id(Suit.clubs, 5)));
    expect(meldsUsingCard(id(Suit.spades, 1), hand), isEmpty);
  });
}