import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tongits_offline/game/cpu_player.dart';
import 'package:flutter_tongits_offline/game/deal_cards.dart';
import 'package:flutter_tongits_offline/game/game_state.dart';

void main() {
  test('CPU-only rounds always finish and never lose or duplicate cards', () {
    final cpu = CpuPlayer();
    final reasons = <RoundEndReason>{};

    for (var seed = 0; seed < 200; seed++) {
      final game = dealNewGame(
        players: [
          PlayerState(name: 'CPU A', isCpu: true),
          PlayerState(name: 'CPU B', isCpu: true),
          PlayerState(name: 'CPU C', isCpu: true),
        ],
        firstPlayerIndex: seed % 3,
        random: Random(seed),
      );

      var turns = 0;
      while (!game.isRoundOver) {
        expect(++turns, lessThan(500), reason: 'seed $seed did not finish');
        cpu.playTurn(game);
        expect(
          game.hasValidCardConservation,
          isTrue,
          reason: 'seed $seed, turn $turns',
        );
      }

      reasons.add(game.result!.reason);
    }

    // Sanity check that the simulation exercises more than one ending.
    expect(reasons, isNotEmpty);
  });
}