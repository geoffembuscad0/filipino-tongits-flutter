import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tongits_offline/game/deal_cards.dart';
import 'package:flutter_tongits_offline/game/game_state.dart';

void main() {
  group('dealNewGame', () {
    test('deals all cards and gives the opening winner first turn', () {
      final players = createDefaultPlayers();
      final game = dealNewGame(
        players: players,
        firstPlayerIndex: 2,
        random: Random(1234),
      );

      expect(players.map((player) => player.name).toList(), [
        'You',
        'CPU Player 1',
        'CPU Player 2',
      ]);
      expect(players.map((player) => player.hand.length), everyElement(12));
      expect(game.stock, hasLength(16));
      expect(game.currentPlayerIndex, 2);
      expect(game.currentPlayer.name, 'CPU Player 2');
      expect(game.phase, TurnPhase.draw);
      expect(game.hasValidCardConservation, isTrue);
    });

    test('deals starting with winner and continues in player order', () {
      const seed = 4321;
      final expectedDeck = List<int>.generate(52, (id) => id)
        ..shuffle(Random(seed));
      final expectedHands = List.generate(3, (_) => <int>[]);
      for (var round = 0; round < 12; round++) {
        for (var offset = 0; offset < 3; offset++) {
          final playerIndex = (1 + offset) % 3;
          expectedHands[playerIndex].add(expectedDeck.removeLast());
        }
      }

      final players = createDefaultPlayers();
      dealNewGame(
        players: players,
        firstPlayerIndex: 1,
        random: Random(seed),
      );

      for (var index = 0; index < players.length; index++) {
        expect(players[index].hand, expectedHands[index]);
      }
    });

    test('rejects an invalid first player index', () {
      expect(
        () => dealNewGame(
          players: createDefaultPlayers(),
          firstPlayerIndex: 3,
          random: Random(1),
        ),
        throwsArgumentError,
      );
    });
  });
}
