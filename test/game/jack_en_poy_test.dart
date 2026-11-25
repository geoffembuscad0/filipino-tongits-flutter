import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tongits_offline/game/jack_en_poy.dart';

class _FixedRandom implements Random {
  _FixedRandom(this.doubleValue, [this.intValue = 0]);

  final double doubleValue;
  final int intValue;

  @override
  int nextInt(int max) => intValue % max;

  @override
  double nextDouble() => doubleValue;

  @override
  bool nextBool() => doubleValue < 0.5;
}

void main() {
  group('JackEnPoyGame', () {
    for (final choice in RpsChoice.values) {
      test('human can win with ${choice.label}', () {
        final result = JackEnPoyGame(
          random: _FixedRandom(0.9),
        ).play(choice);

        expect(result.winnerIndex, 0);
        expect(result.choices.first, choice);
        expect(result.choices[1], choice.defeats);
        expect(result.choices[2], choice.defeats);
        expect(choice.defeats.defeatedBy, choice);
      });

      test('CPU can win against ${choice.label}', () {
        final result = JackEnPoyGame(
          random: _FixedRandom(0.1, 1),
        ).play(choice);

        expect(result.winnerIndex, 2);
        expect(result.choices.first, choice);
        expect(result.choices[2], choice.defeatedBy);
        expect(result.choices[2].defeats, choice);
        expect(result.choices[2].defeats, result.choices[1]);
      });
    }

    test('rejects invalid CPU win probability', () {
      expect(
        () => JackEnPoyGame(cpuWinProbability: 1.1),
        throwsArgumentError,
      );
    });
  });
}
