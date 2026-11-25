import 'dart:async';
import 'dart:math' show max, min;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import 'package:flutter_tongits_offline/game/card.dart';
import 'package:flutter_tongits_offline/game/cpu_player.dart';
import 'package:flutter_tongits_offline/game/game_state.dart';
import 'package:flutter_tongits_offline/table/card_component.dart';

class _Slot {
  const _Slot(this.position, this.faceUp, this.priority);

  final Vector2 position;
  final bool faceUp;
  final int priority;
}

/// A turn-based card table. The rules live in [GameState]; this class only
/// draws them. It keeps its own "visual" copy of where every card is, updates
/// that copy one [GameEvent] at a time, and animates each card to its slot.
///
/// This version plays rounds where every player is a CPU, which is useful for
/// tuning the animations. Human input comes next.
class TongitsTable extends FlameGame {
  TongitsTable({
    required this.state,
    CpuPlayer? cpu,
    bool revealHands = true,
    this.turnPause = const Duration(milliseconds: 500),
    this.stepPause = const Duration(milliseconds: 160),
  }) : cpu = cpu ?? CpuPlayer(),
       _revealHands = revealHands;

  final GameState state;
  final CpuPlayer cpu;

  /// Pause before each CPU "thinks", and between animated steps.
  final Duration turnPause;
  final Duration stepPause;

  static const double _margin = 12;

  bool _revealHands;
  bool _started = false;
  int _activePlayer = 0;
  double _cardW = 68;
  double _cardH = 100;

  final Map<CardId, CardComponent> _cards = {};

  // The visual model: where each card currently is on the table.
  List<CardId> _stock = [];
  List<CardId> _discard = [];
  List<List<CardId>> _hands = [];
  List<List<List<CardId>>> _melds = [];

  late final List<TextComponent> _nameLabels;
  late final TextComponent _status;
  late final TextComponent _stockCount;

  @override
  Color backgroundColor() => const Color(0xFF185447);

  @override
  Future<void> onLoad() async {
    for (var id = 0; id < 52; id++) {
      _cards[id] = CardComponent(id, cardSize: Vector2(68, 100));
    }
    await addAll(_cards.values);

    _nameLabels = [
      for (final player in state.players)
        TextComponent(
          text: player.name,
          anchor: Anchor.center,
          priority: 2000,
          textRenderer: _labelStyle(active: false),
        ),
    ];
    _status = TextComponent(
      text: '',
      anchor: Anchor.center,
      priority: 2000,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFF1D58A),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    _stockCount = TextComponent(
      text: '',
      anchor: Anchor.center,
      priority: 2000,
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
    await addAll([..._nameLabels, _status, _stockCount]);
  }

  @override
  void onMount() {
    super.onMount();
    // Not awaited: onLoad must finish before effects start ticking.
    unawaited(_run());
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_started) {
      _applyMetrics();
      _relayout(snap: true);
    }
  }

  // ---------------------------------------------------------------- round

  Future<void> _run() async {
    while (size.x == 0) {
      if (!isMounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    _applyMetrics();
    _started = true;
    state.events.clear();

    // Every card starts face down on the stock, then is dealt out.
    for (final card in _cards.values) {
      card.snapTo(_stockCenter, faceUp: false);
    }
    _syncVisualFromState();
    _activePlayer = state.currentPlayerIndex;
    _updateNameLabels();
    _setStatus('Dealing…');
    await _relayout(delays: _dealDelays(), seconds: 0.45);

    _setStatus('${state.currentPlayer.name} opens the round');
    await Future<void>.delayed(turnPause);

    while (!state.isRoundOver && isMounted) {
      _activePlayer = state.currentPlayerIndex;
      _updateNameLabels();

      final player = state.currentPlayer;
      if (!player.isCpu) {
        _setStatus('Waiting for ${player.name}…');
        return; // Human turns are not built yet.
      }

      await Future<void>.delayed(turnPause);
      cpu.playTurn(state);
      await _playEvents();
    }

    if (!isMounted) return;
    await _finishRound();
  }

  Future<void> _playEvents() async {
    final events = List<GameEvent>.of(state.events);
    state.events.clear();

    for (final event in events) {
      if (!isMounted) return;
      await _applyEvent(event);
      await Future<void>.delayed(stepPause);
    }
  }

  Future<void> _applyEvent(GameEvent event) async {
    final name = state.players[event.playerIndex].name;

    switch (event) {
      case DrewFromStock():
        _setStatus('$name draws from the stock');
        _stock.remove(event.card);
        _hands[event.playerIndex].add(event.card);
        _sortHand(event.playerIndex);
        await _relayout();

      case DrewFromDiscard():
        _setStatus('$name takes the discard and melds');
        _discard.remove(_discard.last);
        _hands[event.playerIndex].removeWhere(event.meldCards.contains);
        _melds[event.playerIndex].add(_sorted(event.meldCards));
        await _relayout(delays: _staggered(event.meldCards));

      case ExposedMeld():
        _setStatus('$name exposes a meld');
        _hands[event.playerIndex].removeWhere(event.cards.contains);
        _melds[event.playerIndex].add(_sorted(event.cards));
        await _relayout(delays: _staggered(event.cards));

      case LaidOff():
        _setStatus('$name lays off a card');
        _hands[event.playerIndex].remove(event.card);
        _melds[event.ownerIndex][event.meldIndex]
          ..add(event.card)
          ..sort();
        await _relayout();

      case Discarded():
        _setStatus('$name discards');
        _hands[event.playerIndex].remove(event.card);
        _discard.add(event.card);
        await _relayout();

      case DrawCalled():
        _setStatus('$name calls DRAW!');
        await Future<void>.delayed(const Duration(milliseconds: 900));

      case ChallengeAnswered():
        _setStatus('$name ${event.fight ? 'fights' : 'folds'}');
        await Future<void>.delayed(const Duration(milliseconds: 700));
    }
  }

  Future<void> _finishRound() async {
    _revealHands = true;
    await _relayout();
    _setStatus(_resultText());
    _updateNameLabels(roundOver: true);
  }

  String _resultText() {
    final result = state.result!;
    final winner = result.winnerIndex == null
        ? null
        : state.players[result.winnerIndex!].name;
    final points = result.deadwood.join(' / ');

    return switch (result.reason) {
      RoundEndReason.tongits => '$winner wins with Tongits!',
      RoundEndReason.challengeFolded => '$winner wins: everyone folded',
      RoundEndReason.drawChallenge => '$winner wins the Draw ($points)',
      RoundEndReason.stockEmpty =>
        winner == null
            ? 'Stock is empty: tie ($points)'
            : 'Stock is empty: $winner wins ($points)',
    };
  }

  // ------------------------------------------------------- visual model

  void _syncVisualFromState() {
    _stock = List<CardId>.of(state.stock);
    _discard = List<CardId>.of(state.discardPile);
    _hands = [
      for (final player in state.players) List<CardId>.of(player.hand)..sort(),
    ];
    _melds = [
      for (final player in state.players)
        [for (final meld in player.melds) List<CardId>.of(meld.cards)],
    ];
  }

  void _sortHand(int player) => _hands[player].sort();

  List<CardId> _sorted(List<CardId> cards) => List<CardId>.of(cards)..sort();

  /// Cards fan out one after another instead of moving as a block.
  Map<CardId, double> _staggered(List<CardId> cards) => {
    for (var i = 0; i < cards.length; i++) cards[i]: i * 0.07,
  };

  /// Round-robin dealing order, one card at a time.
  Map<CardId, double> _dealDelays() {
    final delays = <CardId, double>{};
    var count = 0;
    for (var round = 0; round < 13; round++) {
      for (var p = 0; p < _hands.length; p++) {
        if (round < _hands[p].length) delays[_hands[p][round]] = count++ * 0.04;
      }
    }
    return delays;
  }

  // -------------------------------------------------------------- layout

  void _applyMetrics() {
    final byWidth = size.x / 8;
    final byHeight = size.y * 0.14 * 0.68;
    _cardW = min(byWidth, byHeight).clamp(30.0, 72.0).toDouble();
    _cardH = _cardW * 100 / 68;

    final cardSize = Vector2(_cardW, _cardH);
    for (final card in _cards.values) {
      card.resize(cardSize);
    }
    _positionLabels();
  }

  Vector2 get _stockCenter => Vector2(size.x / 2 - _cardW * 0.7, size.y * 0.5);

  Vector2 get _discardCenter =>
      Vector2(size.x / 2 + _cardW * 0.7, size.y * 0.5);

  ({double left, double right, double y}) _handArea(int player) {
    final w = size.x;
    final h = size.y;
    return switch (player) {
      0 => (left: _margin, right: w - _margin, y: h * 0.9),
      1 => (left: _margin, right: w / 2 - _margin / 2, y: h * 0.11),
      _ => (left: w / 2 + _margin / 2, right: w - _margin, y: h * 0.11),
    };
  }

  Rect _meldZone(int player) {
    final w = size.x;
    final h = size.y;
    return switch (player) {
      0 => Rect.fromLTWH(_margin, h * 0.585, w - 2 * _margin, h * 0.2),
      1 => Rect.fromLTWH(_margin, h * 0.2, w / 2 - 1.5 * _margin, h * 0.22),
      _ => Rect.fromLTWH(
        w / 2 + 0.5 * _margin,
        h * 0.2,
        w / 2 - 1.5 * _margin,
        h * 0.22,
      ),
    };
  }

  Map<CardId, _Slot> _targets() {
    final out = <CardId, _Slot>{};

    final stockCenter = _stockCenter;
    for (var i = 0; i < _stock.length; i++) {
      out[_stock[i]] = _Slot(
        Vector2(stockCenter.x, stockCenter.y - min(i, 8) * 0.7),
        false,
        i,
      );
    }

    final discardCenter = _discardCenter;
    for (var i = 0; i < _discard.length; i++) {
      final id = _discard[i];
      final jitter = Vector2(
        ((id * 7) % 5 - 2) * 1.2,
        ((id * 3) % 5 - 2) * 1.2,
      );
      out[id] = _Slot(discardCenter + jitter, true, 100 + i);
    }

    for (var p = 0; p < _hands.length; p++) {
      final hand = _hands[p];
      final area = _handArea(p);
      final faceUp = p == 0 || _revealHands;
      final preferred = p == 0
          ? _cardW * 0.95
          : _cardW * (_revealHands ? 0.55 : 0.4);
      final spacing = hand.length <= 1
          ? 0.0
          : max(
              2.0,
              min(preferred, (area.right - area.left - _cardW) / (hand.length - 1)),
            );
      final total = _cardW + (hand.length - 1) * spacing;
      final startX = (area.left + area.right) / 2 - total / 2 + _cardW / 2;

      for (var i = 0; i < hand.length; i++) {
        out[hand[i]] = _Slot(
          Vector2(startX + i * spacing, area.y),
          faceUp,
          400 + p * 20 + i,
        );
      }
    }

    for (var p = 0; p < _melds.length; p++) {
      _layoutMelds(_meldZone(p), _melds[p], out, 200 + p * 60);
    }

    return out;
  }

  /// Melds flow left to right and wrap onto new rows when the zone is full.
  void _layoutMelds(
    Rect zone,
    List<List<CardId>> melds,
    Map<CardId, _Slot> out,
    int priorityBase,
  ) {
    if (melds.isEmpty) return;

    final step = _cardW * 0.42;
    final gap = _cardW * 0.35;
    double widthOf(List<CardId> meld) => _cardW + (meld.length - 1) * step;

    final rows = <List<int>>[<int>[]];
    var x = 0.0;
    for (var i = 0; i < melds.length; i++) {
      final w = widthOf(melds[i]);
      if (rows.last.isNotEmpty && x + gap + w > zone.width) {
        rows.add(<int>[]);
        x = 0;
      }
      if (rows.last.isNotEmpty) x += gap;
      rows.last.add(i);
      x += w;
    }

    final rowGap = rows.length == 1
        ? 0.0
        : max(
            _cardH * 0.3,
            min(_cardH * 1.08, (zone.height - _cardH) / (rows.length - 1)),
          );

    var order = 0;
    for (var r = 0; r < rows.length; r++) {
      var rowWidth = gap * (rows[r].length - 1);
      for (final i in rows[r]) {
        rowWidth += widthOf(melds[i]);
      }

      var cursor = zone.center.dx - rowWidth / 2;
      for (final i in rows[r]) {
        for (var j = 0; j < melds[i].length; j++) {
          out[melds[i][j]] = _Slot(
            Vector2(
              cursor + _cardW / 2 + j * step,
              zone.top + _cardH / 2 + r * rowGap,
            ),
            true,
            priorityBase + order++,
          );
        }
        cursor += widthOf(melds[i]) + gap;
      }
    }
  }

  /// Moves every card to the slot the visual model assigns it. Cards that do
  /// not need to move stay put, so a hand closes up smoothly around a gap.
  Future<void> _relayout({
    bool snap = false,
    Map<CardId, double> delays = const {},
    double seconds = 0.4,
  }) {
    final futures = <Future<void>>[];

    _targets().forEach((id, slot) {
      final card = _cards[id]!;
      card.restPriority = slot.priority;

      if (snap) {
        card.snapTo(slot.position, faceUp: slot.faceUp);
        card.priority = slot.priority;
        return;
      }

      final delay = delays[id] ?? 0.0;
      futures.add(card.moveTo(slot.position, seconds: seconds, delay: delay));
      if (card.faceUp != slot.faceUp) {
        futures.add(card.flipTo(slot.faceUp, delay: delay));
      }
    });

    _stockCount.text = '${_stock.length}';
    return Future.wait(futures);
  }

  // -------------------------------------------------------------- labels

  TextPaint _labelStyle({required bool active}) => TextPaint(
    style: TextStyle(
      color: active ? const Color(0xFFF1D58A) : Colors.white70,
      fontSize: 13,
      fontWeight: active ? FontWeight.bold : FontWeight.w500,
    ),
  );

  void _positionLabels() {
    for (var p = 0; p < _nameLabels.length; p++) {
      final area = _handArea(p);
      _nameLabels[p].position = Vector2(
        (area.left + area.right) / 2,
        area.y - _cardH / 2 - 12,
      );
    }
    _status.position = Vector2(size.x / 2, size.y * 0.5 - _cardH / 2 - 16);
    _stockCount.position = Vector2(
      size.x / 2 - _cardW * 0.7,
      size.y * 0.5 + _cardH / 2 + 12,
    );
  }

  void _updateNameLabels({bool roundOver = false}) {
    for (var p = 0; p < _nameLabels.length; p++) {
      _nameLabels[p].textRenderer = _labelStyle(
        active: !roundOver && p == _activePlayer,
      );
    }
  }

  void _setStatus(String text) => _status.text = text;
}