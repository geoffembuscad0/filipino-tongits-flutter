import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flame/components.dart';

import '../game/card.dart';
import '../game/cpu_player.dart';
import '../game/deal_cards.dart';
import '../game/game_event.dart';
import '../game/game_state.dart';
import 'card_component.dart';

/// Portrait-first Flame table. The engine resolves a whole CPU turn at once;
/// this component then replays its immutable event snapshots in order.
class TongitsTable extends FlameGame {
  TongitsTable({Random? random})
      : game = dealNewGame(
          players: createCpuDemoPlayers(),
          firstPlayerIndex: 0,
          random: random,
        );

  final GameState game;
  final CpuPlayer _cpu = CpuPlayer();

  final Map<CardId, CardComponent> _cards = {};
  final List<List<CardId>> _visualHands = [[], [], []];
  final List<List<CardId>> _visualMelds = [];
  final List<CardId> _visualDiscard = [];

  bool _running = false;
  bool _busy = false;
  String _status = 'Dealing cards…';

  Vector2 get _stockPosition => Vector2(size.x * .5 - 43, size.y * .48);
  Vector2 get _discardPosition => Vector2(size.x * .5 + 43, size.y * .48);

  @override
  Color backgroundColor() => const Color(0xFF185447);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    for (var id = 0; id < 52; id++) {
      final component = CardComponent(id)
        ..position = _stockPosition
        ..faceUp = false;
      _cards[id] = component;
      await add(component);
    }

    // Let Flame lay out the first frame before starting asynchronous playback.
    unawaited(_runRound());
  }

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    if (_cards.isNotEmpty) {
      _relayoutHands(animate: false);
      _relayoutMelds(animate: false);
      for (final card in _visualDiscard) {
        _cards[card]?.position = _discardPosition;
      }
    }
  }

  Future<void> _runRound() async {
    if (_running) return;
    _running = true;

    await _playEvents();

    while (!game.isRoundOver) {
      await Future<void>.delayed(const Duration(milliseconds: 420));
      _cpu.playTurn(game);
      await _playEvents();
    }

    _status = _resultLabel();
    _running = false;
  }

  Future<void> _playEvents() async {
    final pending = game.takeEvents();
    if (pending.isEmpty) return;

    _busy = true;
    for (final event in pending) {
      switch (event) {
        case DealtCard():
          await _dealCard(event);
        case DrewFromStock():
          await _drawToHand(event.playerIndex, event.card);
        case DrewFromDiscard():
          await _drawDiscardMeld(event);
        case ExposedMeld():
          await _exposeMeld(event);
        case LaidOff():
          await _layOff(event);
        case Discarded():
          await _discard(event);
        case CalledDraw():
          _status = '${game.players[event.playerIndex].name} calls DRAW';
        case ChallengeResponseRecorded():
          _status =
              '${game.players[event.playerIndex].name}: ${event.fight ? 'FIGHT' : 'FOLD'}';
        case RoundFinished():
          _status = _resultLabel();
      }

      await _relayoutHands();
      await _relayoutMelds();
      await Future<void>.delayed(const Duration(milliseconds: 90));
    }
    _busy = false;
  }

  Future<void> _dealCard(DealtCard event) async {
    final hand = _visualHands[event.playerIndex]..add(event.card);
    final target = _handPosition(event.playerIndex, hand.length - 1, hand.length);
    final component = _cards[event.card]!..faceUp = false;
    await component.moveTo(target, seconds: .18, delay: .035);
  }

  Future<void> _drawToHand(int playerIndex, CardId cardId) async {
    final hand = _visualHands[playerIndex]..add(cardId);
    final target = _handPosition(playerIndex, hand.length - 1, hand.length);
    final component = _cards[cardId]!..faceUp = false;
    await component.moveTo(target, seconds: .24);
  }

  Future<void> _drawDiscardMeld(DrewFromDiscard event) async {
    final cards = event.meldCards;
    final discardedCard = cards.where(_visualDiscard.contains).firstOrNull;
    if (discardedCard != null) _visualDiscard.remove(discardedCard);
    for (final card in cards) {
      _visualHands[event.playerIndex].remove(card);
    }
    _visualMelds.add(List<CardId>.of(cards));
    for (var i = 0; i < cards.length; i++) {
      final component = _cards[cards[i]]!..faceUp = true;
      await component.moveTo(
        _meldPosition(_visualMelds.length - 1, i, cards.length),
        seconds: .22,
        delay: i * .045,
      );
    }
  }

  Future<void> _exposeMeld(ExposedMeld event) async {
    final cards = event.cards;
    for (final card in cards) {
      _visualHands[event.playerIndex].remove(card);
    }
    _visualMelds.add(List<CardId>.of(cards));
    await Future.wait([
      for (var i = 0; i < cards.length; i++)
        _moveCardIntoMeld(
          cards[i],
          _meldPosition(_visualMelds.length - 1, i, cards.length),
          delay: i * .05,
        ),
    ]);
  }


  Future<void> _moveCardIntoMeld(
    CardId cardId,
    Vector2 target, {
    double delay = 0,
  }) {
    final component = _cards[cardId]!..faceUp = true;
    return component.moveTo(target, seconds: .24, delay: delay);
  }

  Future<void> _layOff(LaidOff event) async {
    _visualHands[event.playerIndex].remove(event.card);
    var targetIndex = _visualMelds.indexWhere(
      (meld) => event.meldCardsAfter.any(meld.contains),
    );
    if (targetIndex < 0) {
      targetIndex = _visualMelds.length;
      _visualMelds.add([]);
    }
    final meld = _visualMelds[targetIndex];
    if (!meld.contains(event.card)) meld.add(event.card);
    final component = _cards[event.card]!..faceUp = true;
    await component.moveTo(
      _meldPosition(targetIndex, meld.indexOf(event.card), meld.length),
    );
  }

  Future<void> _discard(Discarded event) async {
    _visualHands[event.playerIndex].remove(event.card);
    _visualDiscard.add(event.card);
    final component = _cards[event.card]!..faceUp = true;
    await component.moveTo(_discardPosition, seconds: .22);
  }

  Vector2 _handPosition(int player, int index, int count) {
    final spacing = min(25.0, (size.x - 34) / max(1, count));
    final total = spacing * (count - 1);
    final x = size.x / 2 - total / 2 + index * spacing;
    final y = switch (player) {
      0 => size.y - 92,
      1 => 82.0,
      _ => size.y * .25,
    };
    return Vector2(x, y);
  }

  Vector2 _meldPosition(int meldIndex, int cardIndex, int count) {
    final spacing = 22.0;
    final x = size.x / 2 - (count - 1) * spacing / 2 + cardIndex * spacing;
    final y = size.y * .48 + 82 + meldIndex * 48;
    return Vector2(x, min(y, size.y - 190));
  }

  Future<void> _relayoutHands({bool animate = true}) async {
    final moves = <Future<void>>[];
    for (var player = 0; player < _visualHands.length; player++) {
      final hand = _visualHands[player];
      for (var i = 0; i < hand.length; i++) {
        final component = _cards[hand[i]]!;
        final target = _handPosition(player, i, hand.length);
        if (animate) {
          moves.add(component.moveTo(target, seconds: .16));
        } else {
          component.position = target;
        }
      }
    }
    if (animate && moves.isNotEmpty) await Future.wait(moves);
  }

  Future<void> _relayoutMelds({bool animate = true}) async {
    final moves = <Future<void>>[];
    for (var meldIndex = 0; meldIndex < _visualMelds.length; meldIndex++) {
      final meld = _visualMelds[meldIndex];
      for (var i = 0; i < meld.length; i++) {
        final component = _cards[meld[i]]!;
        final target = _meldPosition(meldIndex, i, meld.length);
        if (animate) {
          moves.add(component.moveTo(target, seconds: .14));
        } else {
          component.position = target;
        }
      }
    }
    if (animate && moves.isNotEmpty) await Future.wait(moves);
  }

  String _resultLabel() {
    final result = game.result;
    if (result == null) return _status;
    if (result.winnerIndex == null) return 'Round tied — stock empty';
    return '${game.players[result.winnerIndex!].name} wins (${result.reason.name})';
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _drawLabel(canvas, _status, Offset(12, 12), 15, const Color(0xFFFFE5A6));
    _drawLabel(
      canvas,
      'STOCK ${game.stock.length}   •   DISCARD ${_visualDiscard.length}',
      Offset(12, 34),
      11,
      const Color(0xFFE7F0E9),
    );
    if (_busy) {
      _drawLabel(
        canvas,
        'Resolving turn…',
        Offset(size.x / 2 - 42, size.y * .48 - 65),
        11,
        const Color(0xFFFFE5A6),
      );
    }
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset offset,
    double fontSize,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x - 24);
    painter.paint(canvas, offset);
  }
}
