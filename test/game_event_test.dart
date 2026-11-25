import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tongits_offline/game/deal_cards.dart';
import 'package:flutter_tongits_offline/game/game_event.dart';
import 'package:flutter_tongits_offline/game/game_state.dart';

void main() {
  test('dealing records one event for each dealt card in deal order', () {
    final game = dealNewGame(
      players: createCpuDemoPlayers(),
      firstPlayerIndex: 0,
      random: Random(7),
    );

    final dealt = game.events.whereType<DealtCard>().toList();
    expect(dealt, hasLength(37));
    expect(dealt.where((event) => event.playerIndex == 0), hasLength(13));
    expect(dealt.where((event) => event.playerIndex == 1), hasLength(12));
    expect(dealt.where((event) => event.playerIndex == 2), hasLength(12));
    expect(dealt.map((event) => event.card).toSet(), hasLength(37));
  });

  test('drawing from stock records the exact player and card', () {
    final game = dealNewGame(
      players: createCpuDemoPlayers(),
      firstPlayerIndex: 0,
      random: Random(11),
    );
    game.takeEvents();

    // The opening player starts in play; move to the next player's draw phase
    // through a legal discard.
    final firstCard = game.currentPlayer.hand.first;
    game.discardFromHand(firstCard);
    game.takeEvents();

    final playerIndex = game.currentPlayerIndex;
    final drawn = game.stock.last;
    expect(game.drawFromStock(), drawn);

    expect(game.events, hasLength(1));
    expect(game.events.single, isA<DrewFromStock>());
    final event = game.events.single as DrewFromStock;
    expect(event.playerIndex, playerIndex);
    expect(event.card, drawn);
  });
}
