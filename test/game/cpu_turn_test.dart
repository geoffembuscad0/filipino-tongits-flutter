import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tongits_offline/game/cpu_player.dart';
import 'package:flutter_tongits_offline/game/cpu_turn_controller.dart';
import 'package:flutter_tongits_offline/game/deal_cards.dart';
import 'package:flutter_tongits_offline/game/game_state.dart';

void main() {
  test('finishTurnNow always ends a CPU turn validly', () {
    for (var seed = 0; seed < 60; seed++) {
      final game = dealNewGame(
        players: createDefaultPlayers(),
        firstPlayerIndex: 1,
        random: Random(seed),
      );
      final cpu = CpuPlayer();

      // Dealer opening (discard phase), then both CPUs from the draw phase,
      // sometimes interrupted right after the draw.
      cpu.finishTurnNow(game);
      expect(game.hasValidCardConservation, isTrue);
      if (game.phase == TurnPhase.roundOver) continue;

      cpu.finishTurnNow(game); // CPU Player 2
      if (game.phase == TurnPhase.roundOver) continue;
      game.drawFromStock(); // You draw, then discard anything
      game.discardFromHand(game.currentPlayer.hand.first);

      cpu.drawStep(game); // CPU 1 draws, then the budget runs out
      cpu.finishTurnNow(game);

      expect(game.hasValidCardConservation, isTrue);
      expect(game.pendingDiscardCard, isNull);
    }
  });

  test('playTurn completes whole turns without breaking the rules', () {
    final game = dealNewGame(
      players: createDefaultPlayers(),
      firstPlayerIndex: 1,
      random: Random(99),
    );
    final cpu = CpuPlayer();

    for (var turn = 0; turn < 30; turn++) {
      if (game.phase == TurnPhase.roundOver) break;
      if (game.currentPlayer.isCpu) {
        cpu.playTurn(game);
      } else {
        game.drawFromStock();
        if (game.phase == TurnPhase.discard) {
          game.discardFromHand(game.currentPlayer.hand.first);
        }
      }
      expect(game.hasValidCardConservation, isTrue);
    }
  });

  testWidgets('timer forces a valid finish when the budget runs out', (
    tester,
  ) async {
    final game = dealNewGame(
      players: createDefaultPlayers(),
      firstPlayerIndex: 1,
      random: Random(7),
    );
    final controller = CpuTurnController(
      game: game,
      turnLimit: const Duration(seconds: 2),
      stepDelay: const Duration(seconds: 10),
    );

    unawaited(controller.startTurn());
    await tester.pump(const Duration(seconds: 3));

    expect(controller.isRunning, isFalse);
    expect(game.currentPlayerIndex, 2);
    expect(game.phase, TurnPhase.draw);
    expect(game.hasValidCardConservation, isTrue);

    await tester.pump(const Duration(seconds: 10)); // let the stale step wake
    controller.dispose();
  });
}