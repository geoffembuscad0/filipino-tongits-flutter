import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tongits_offline/game/meld_rules.dart';

// Ids: clubs 0-12, diamonds 13-25, hearts 26-38, spades 39-51; Ace first.
void main() {
  group('classifyMeld', () {
    test('accepts sets of 3 and 4', () {
      expect(classifyMeld([6, 19, 32]), MeldKind.set);
      expect(classifyMeld([6, 19, 32, 45]), MeldKind.set);
    });

    test('accepts runs with Ace low only', () {
      expect(classifyMeld([0, 1, 2]), MeldKind.run); // A-2-3 clubs
      expect(classifyMeld([10, 11, 12]), MeldKind.run); // J-Q-K clubs
      expect(classifyMeld([11, 12, 0]), isNull); // Q-K-A wraps
    });

    test('rejects mixed suits, gaps and short groups', () {
      expect(classifyMeld([0, 14, 2]), isNull);
      expect(classifyMeld([0, 1, 3]), isNull);
      expect(classifyMeld([0, 1]), isNull);
    });
  });

  group('findBestMelds', () {
    test('uses a four of a kind card in a run when that scores more', () {
      // 5C 5D 5H 5S plus 6C 7C -> run 5-6-7 clubs + set of three 5s.
      final hand = [4, 17, 30, 43, 5, 6];
      final melds = findBestMelds(hand);
      final used = melds.expand((m) => m).toSet();
      expect(used, hasLength(6));
    });

    test('mustInclude returns empty when the card cannot be melded', () {
      expect(findBestMelds([0, 14, 28, 41], mustInclude: 41), isEmpty);
    });
  });

  test('canFormMeldWith', () {
    expect(canFormMeldWith(2, [0, 1, 20]), isTrue);
    expect(canFormMeldWith(50, [0, 1, 20]), isFalse);
  });
}