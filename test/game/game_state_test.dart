import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tongits_offline/game/card.dart';
import 'package:flutter_tongits_offline/game/game_state.dart';

int id(Suit suit, int rank) => suit.index * 13 + rank - 1;

GameState gameWith({
  List<CardId> hand0 = const [],
  List<CardId> hand1 = const [],
  List<CardId> hand2 = const [],
  List<CardId> stock = const [],
  TurnPhase phase = TurnPhase.draw,
}) {
  final players = [
    PlayerState(name: 'You', isCpu: false)..hand.addAll(hand0),
    PlayerState(name: 'CPU Player 1', isCpu: true)..hand.addAll(hand1),
    PlayerState(name: 'CPU Player 2', isCpu: true)..hand.addAll(hand2),
  ];
  return GameState(
    players: players,
    stock: List<CardId>.of(stock),
    random: Random(1),
    currentPlayerIndex: 0,
    phase: phase,
  );
}

void main() {
  final c3 = id(Suit.clubs, 3);
  final c4 = id(Suit.clubs, 4);
  final c5 = id(Suit.clubs, 5);
  final c6 = id(Suit.clubs, 6);
  final d9 = id(Suit.diamonds, 9);

  test('exposing every card ends the round with Tongits', () {
    final game = gameWith(hand0: [c3, c4, c5], phase: TurnPhase.play);

    game.exposeMeld([c3, c4, c5]);

    expect(game.isRoundOver, isTrue);
    expect(game.result!.winnerIndex, 0);
    expect(game.result!.reason, RoundEndReason.tongits);
  });

  test('exposeMeld rejects invalid melds and cards not in hand', () {
    final game = gameWith(hand0: [c3, c4, d9], phase: TurnPhase.play);

    expect(() => game.exposeMeld([c3, c4, d9]), throwsArgumentError);
    expect(() => game.exposeMeld([c3, c4, c5]), throwsArgumentError);
  });

  test('top discard can only be taken as part of a meld', () {
    final game = gameWith(hand0: [c3, c4, d9]);
    game.discardPile.add(c5);

    expect(() => game.drawFromDiscard([c3, c5]), throwsArgumentError);
    expect(() => game.drawFromDiscard([c3, c4, d9]), throwsArgumentError);

    game.drawFromDiscard([c3, c4, c5]);

    expect(game.currentPlayer.hand, [d9]);
    expect(game.currentPlayer.melds, hasLength(1));
    expect(game.discardPile, isEmpty);
    expect(game.phase, TurnPhase.play);
  });

  test('discarding passes the turn', () {
    final game = gameWith(hand0: [c3, d9], phase: TurnPhase.play);

    game.discardFromHand(d9);

    expect(game.currentPlayerIndex, 1);
    expect(game.phase, TurnPhase.draw);
    expect(game.discardPile, [d9]);
  });

  test('cards can be laid off on another player’s meld', () {
    final game = gameWith(hand0: [c6, d9], phase: TurnPhase.play);
    final meld = Meld(cards: [c3, c4, c5], kind: MeldKind.run);
    game.players[1].melds.add(meld);

    expect(() => game.layOff(d9, meld), throwsArgumentError);

    game.layOff(c6, meld);

    expect(meld.cards, [c3, c4, c5, c6]);
    expect(game.currentPlayer.hand, [d9]);
  });

  group('Draw challenge', () {
    GameState challengeGame({required int h0, required int h1, required int h2}) {
      final game = gameWith(hand0: [h0], hand1: [h1], hand2: [h2]);
      game.players[0].melds.add(
        Meld(cards: [c3, c4, c5], kind: MeldKind.run),
      );
      return game;
    }

    test('requires an exposed meld', () {
      expect(() => gameWith().callDraw(), throwsStateError);
    });

    test('lowest deadwood among caller and fighters wins', () {
      final game = challengeGame(
        h0: id(Suit.clubs, 1),
        h1: id(Suit.spades, 13),
        h2: id(Suit.spades, 12),
      )..callDraw();

      game.respondToChallenge(1, fight: true);
      expect(game.pendingChallengeResponders, [2]);
      game.respondToChallenge(2, fight: true);

      expect(game.result!.winnerIndex, 0);
      expect(game.result!.reason, RoundEndReason.drawChallenge);
    });

    test('a tie goes to the fighter, not the caller', () {
      final game = challengeGame(
        h0: id(Suit.clubs, 5),
        h1: id(Suit.diamonds, 5),
        h2: id(Suit.spades, 13),
      )..callDraw();

      game.respondToChallenge(1, fight: true);
      game.respondToChallenge(2, fight: false);

      expect(game.result!.winnerIndex, 1);
    });

    test('caller wins when everyone folds', () {
      final game = challengeGame(
        h0: id(Suit.clubs, 13),
        h1: id(Suit.diamonds, 1),
        h2: id(Suit.spades, 1),
      )..callDraw();

      game.respondToChallenge(1, fight: false);
      game.respondToChallenge(2, fight: false);

      expect(game.result!.winnerIndex, 0);
      expect(game.result!.reason, RoundEndReason.challengeFolded);
    });
  });

  test('an empty stock ends the round; lowest deadwood wins', () {
    final game = gameWith(
      hand0: [id(Suit.clubs, 2)],
      hand1: [id(Suit.clubs, 3)],
      hand2: [id(Suit.clubs, 4)],
    );

    expect(game.drawFromStock(), isNull);
    expect(game.result!.winnerIndex, 0);
    expect(game.result!.reason, RoundEndReason.stockEmpty);
  });

  test('an empty stock with tied lowest deadwood has no winner', () {
    final game = gameWith(
      hand0: [id(Suit.clubs, 2)],
      hand1: [id(Suit.diamonds, 2)],
      hand2: [id(Suit.clubs, 4)],
    );

    game.drawFromStock();
    expect(game.result!.winnerIndex, isNull);
  });
}