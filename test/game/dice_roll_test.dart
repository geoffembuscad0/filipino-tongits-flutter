import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tongits_offline/game/deal_cards.dart';
import 'package:flutter_tongits_offline/game/dice_roll.dart';

void main() {
  group('DiceDealerSelection', () {
    test('rolls two six-sided dice for each participant', () {
      final selection = DiceDealerSelection(random: Random(12));
      final results = selection.roll([0, 1, 2]);

      expect(results, hasLength(3));

      for (final result in results) {
        expect(result.firstDie, inInclusiveRange(1, 6));
        expect(result.secondDie, inInclusiveRange(1, 6));
        expect(result.total, inInclusiveRange(2, 12));
      }
    });

    test('lowestIndices returns every participant tied for the lowest', () {
      final results = const [
        DiceRollResult(playerIndex: 0, firstDie: 3, secondDie: 4),
        DiceRollResult(playerIndex: 1, firstDie: 1, secondDie: 2),
        DiceRollResult(playerIndex: 2, firstDie: 2, secondDie: 1),
      ];

      expect(
        DiceDealerSelection().lowestIndices(results),
        equals([1, 2]),
      );
    });
  });

  group('Dealer rotation', () {
    test('moves clockwise through the three player seats', () {
      expect(nextDealerIndex(0), 1);
      expect(nextDealerIndex(1), 2);
      expect(nextDealerIndex(2), 0);
    });
  });
}