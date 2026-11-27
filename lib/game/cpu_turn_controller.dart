import 'dart:async';

import 'package:flutter/foundation.dart';

import 'card.dart';
import 'cpu_player.dart';
import 'game_state.dart';

/// Runs one CPU turn step by step (so the table can animate each action)
/// under a single time budget covering draw, melds, layoffs and discard.
///
/// If the budget hits zero mid-turn, [CpuPlayer.finishTurnNow] completes
/// the required actions immediately, so a timeout never leaves the game in
/// an invalid or stuck state.
class CpuTurnController {
  CpuTurnController({
    required this.game,
    CpuPlayer? cpu,
    this.turnLimit = const Duration(seconds: 15),
    this.stepDelay = const Duration(milliseconds: 900),
    this.onChanged,
  }) : cpu = cpu ?? CpuPlayer(),
       secondsLeft = ValueNotifier<int>(turnLimit.inSeconds);

  static const Duration _tick = Duration(milliseconds: 250);

  final GameState game;
  final CpuPlayer cpu;
  final Duration turnLimit;
  final Duration stepDelay;

  /// Called after every game-state change made by the controller.
  final VoidCallback? onChanged;

  /// Whole seconds left in the active CPU's turn (rounded up).
  final ValueNotifier<int> secondsLeft;

  /// Last thing that happened at the table, e.g. "CPU Player 1 discarded 7♠".
  final ValueNotifier<String> status = ValueNotifier<String>('');

  Timer? _ticker;
  Duration _remaining = Duration.zero;
  int _turnId = 0;
  bool _disposed = false;
  bool _responding = false;

  bool get isRunning => _ticker != null;

  Future<void> startTurn() async {
    if (_disposed || _ticker != null) return;
    if (!game.currentPlayer.isCpu) return;
    if (game.phase == TurnPhase.roundOver ||
        game.phase == TurnPhase.challenge) {
      return;
    }

    final turnId = ++_turnId;
    final name = game.currentPlayer.name;

    _remaining = turnLimit;
    secondsLeft.value = _secondsFor(_remaining);
    _ticker = Timer.periodic(_tick, (_) {
      _remaining -= _tick;
      if (_remaining <= Duration.zero) {
        _timeOut(turnId);
      } else {
        secondsLeft.value = _secondsFor(_remaining);
      }
    });

    try {
      await _runSteps(turnId, name);
    } catch (error, stack) {
      debugPrint('CPU turn failed for $name: $error\n$stack');
      _recover(turnId, name);
    }
  }

  Future<void> _runSteps(int turnId, String name) async {
    bool alive() => !_disposed && turnId == _turnId;
    Future<bool> pause() async {
      await Future<void>.delayed(stepDelay);
      return alive();
    }

    bool over() => game.phase == TurnPhase.roundOver;

    if (!await pause()) return;

    // 0. A confident CPU calls Draw instead of drawing.
    if (game.phase == TurnPhase.draw && cpu.shouldCallDraw(game)) {
      game.callDraw();
      status.value = '$name called DRAW!';
      return _endTurn();
    }

    // 1. Draw (the dealer's opening turn skips this).
    if (game.phase == TurnPhase.draw) {
      final fromDiscard = cpu.drawStep(game);
      status.value = fromDiscard
          ? '$name took ${PlayingCard(game.currentPlayer.hand.last)} '
                'from the discard pile'
          : '$name drew from the stock';
      if (over()) return _endTurn();
      onChanged?.call();
      if (!await pause()) return;
    }

    // 2. Check for and place melds.
    for (final plan in cpu.planMelds(game)) {
      final meld = game.layMeld(plan);
      status.value = '$name laid down a ${meld.kind.name}';
      if (over()) return _endTurn();
      onChanged?.call();
      if (!await pause()) return;
    }

    // 3. Lay off cards on exposed melds.
    while (true) {
      final move = cpu.nextLayOff(game);
      if (move == null) break;
      game.layOff(move.card, move.ownerIndex, move.meldIndex);
      status.value = '$name laid off ${PlayingCard(move.card)}';
      if (over()) return _endTurn();
      onChanged?.call();
      if (!await pause()) return;
    }

    // 4. Discard and end the turn.
    final card = cpu.discardStep(game);
    status.value = '$name discarded ${PlayingCard(card)}';
    _endTurn();
  }

  /// Answers a Draw challenge for every CPU that still has to respond, one
  /// at a time. The human answers through the UI; this simply waits for them.
  Future<void> runChallengeResponses() async {
    if (_disposed || _responding || game.phase != TurnPhase.challenge) return;

    _responding = true;
    try {
      while (!_disposed && game.phase == TurnPhase.challenge) {
        int? next;
        for (final index in game.pendingChallengeResponders) {
          if (game.players[index].isCpu) {
            next = index;
            break;
          }
        }
        if (next == null) break; // Waiting on the human, or already resolved.

        await Future<void>.delayed(stepDelay);
        if (_disposed || game.phase != TurnPhase.challenge) break;

        final name = game.players[next].name;
        final fight = cpu.shouldFight(game, next);
        game.respondToChallenge(next, fight);
        status.value = fight ? '$name chose to FIGHT!' : '$name folded.';
        onChanged?.call();
      }
    } catch (error, stack) {
      debugPrint('CPU challenge response failed: $error\n$stack');
      if (!_disposed) {
        game.forceEndTurn();
        onChanged?.call();
      }
    } finally {
      _responding = false;
    }
  }

  void _endTurn() {
    _stopClock();
    onChanged?.call();
  }

  void _timeOut(int turnId) {
    if (_disposed || turnId != _turnId) return;

    _stopClock();
    secondsLeft.value = 0;

    final name = game.currentPlayer.name;
    try {
      cpu.finishTurnNow(game);
    } catch (error, stack) {
      debugPrint('CPU timeout fallback failed for $name: $error\n$stack');
      game.forceEndTurn();
    }
    status.value = '$name ran out of time and finished the turn';
    onChanged?.call();
  }

  /// A step threw: finish the turn immediately so the game never stalls.
  void _recover(int turnId, String name) {
    if (_disposed || turnId != _turnId) return;

    _stopClock();
    try {
      cpu.finishTurnNow(game);
    } catch (error, stack) {
      debugPrint('CPU recovery failed for $name: $error\n$stack');
      game.forceEndTurn();
    }
    status.value = '$name finished the turn';
    onChanged?.call();
  }

  /// Stops the countdown and invalidates any in-flight step sequence.
  void _stopClock() {
    _ticker?.cancel();
    _ticker = null;
    _turnId++;
  }

  int _secondsFor(Duration d) => (d.inMilliseconds / 1000).ceil();

  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _ticker = null;
    secondsLeft.dispose();
    status.dispose();
  }
}