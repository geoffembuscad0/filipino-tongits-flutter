import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tongits_offline/game/deal_cards.dart';
import 'package:flutter_tongits_offline/game/game_state.dart';

// Ids: clubs 0-12, diamonds 13-25, hearts 26-38, spades 39-51; Ace first.
GameState _game({
  required List<int> caller,
  required List<int> other1,
  required List<int> other2,
  bool callerHasMeld = true,
}) {
  final players = createDefaultPlayers();
  players[0].hand.addAll(caller);
  players[1].hand.addAll(other1);
  players[2].hand.addAll(other2);
  if (callerHasMeld) {
    players[0].melds.add(Meld(cards: [20, 21, 22], kind: MeldKind.run));
  }
  return GameState(
    players: players,
    stock: [],
    random: Random(1),
    currentPlayerIndex: 0,
  );
}

void main() {
  test('cannot call Draw without an exposed meld', () {
    final game = _game(caller: [3], other1: [4], other2: [5], callerHasMeld: false);
    expect(game.canCallDraw, isFalse);
    expect(game.callDraw, throwsStateError);
  });

  test('everyone folding gives the caller the win', () {
    final game = _game(caller: [12], other1: [0], other2: [1]);
    game.callDraw();
    expect(game.phase, TurnPhase.challenge);
    expect(game.pendingChallengeResponders, [1, 2]);

    game.respondToChallenge(1, false);
    game.respondToChallenge(2, false);

    expect(game.phase, TurnPhase.roundOver);
    expect(game.winnerIndex, 0);
    expect(game.endReason, RoundEndReason.challengeFolded);
  });

  test('lowest fighting hand wins and folders lose', () {
    final game = _game(caller: [12], other1: [11], other2: [0]); // 10 vs 10 vs 1
    game.callDraw();
    game.respondToChallenge(1, false);
    game.respondToChallenge(2, true);

    expect(game.winnerIndex, 2);
    expect(game.endReason, RoundEndReason.drawChallenge);
  });

  test('a tie goes against the caller', () {
    final game = _game(caller: [3], other1: [16], other2: [12]); // 4 vs 4 vs 10
    game.callDraw();
    game.respondToChallenge(1, true);
    game.respondToChallenge(2, false);

    expect(game.winnerIndex, 1);
  });

  test('fighters tied below the caller is a draw', () {
    final game = _game(caller: [12], other1: [3], other2: [16]); // 10 vs 4 vs 4
    game.callDraw();
    game.respondToChallenge(1, true);
    game.respondToChallenge(2, true);

    expect(game.winnerIndex, isNull);
    expect(game.endReason, RoundEndReason.drawChallenge);
  });

  test('only pending players can answer, and only once', () {
    final game = _game(caller: [12], other1: [0], other2: [1]);
    game.callDraw();
    expect(() => game.respondToChallenge(0, true), throwsStateError);
    game.respondToChallenge(1, true);
    expect(() => game.respondToChallenge(1, false), throwsStateError);
  });
}
/**
* I've added the Draw challenge (Fight or Fold) on top of your latest repo code, in five updated files plus a new test file. I haven't run or compiled any of it, so it needs your flutter analyze and flutter test first.
How it plays

Calling Draw: at the start of your turn, before drawing, if you have at least one exposed meld, a CALL DRAW button appears in the action panel. The dealer's opening turn can't call it.
Answering: the other players answer Fight or Fold. You get a dialog showing your points, and the CPUs answer on their own one after another.
Everyone folds: the caller wins.
Otherwise: the caller and the players who chose Fight compare hands, and the lowest total wins. Folders lose.
Ties: a tie goes against the caller. If two fighters tie below the caller, it's a draw.
Result dialog: it marks who called Draw, who folded and who fought. The CPU hands flip face up for the showdown, and this also applies to Tongits and the stock-empty ending.

CPU behavior

A CPU calls Draw at the start of its turn when it has an exposed meld and its hand is worth 12 points or less.
A CPU fights when its own hand is 12 points or less, and folds otherwise.
Both numbers are named constants at the top of CpuPlayer, so you can tune them.

Lastly, COMMIT MO ITO BRO AFTER MO BUMANGON SA UMAGA!
 */