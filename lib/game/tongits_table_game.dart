import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'card.dart';
import 'game_state.dart';

enum CardZone { stock, discard, hand, opponentHand, meld }

/// A landscape Tongits table drawn with Flame.
///
/// The table owns no rules. Every frame it reads [game], works out where each
/// of the 52 cards belongs (stock, discard, a hand or a meld) and eases the
/// card sprites toward those spots, so dealing, drawing, melding and
/// discarding animate on their own whenever the game state changes.
///
/// Seats: player 0 (you) bottom, player 1 left, player 2 right.
class TongitsTableGame extends FlameGame {
  TongitsTableGame({
    required this.game,
    required this.selected,
    this.onStockTap,
    this.onDiscardTap,
    this.onHandCardTap,
    this.onMeldTap,
  });

  final GameState game;

  /// Cards the human has selected; selected cards are raised.
  final Set<CardId> selected;

  final VoidCallback? onStockTap;
  final VoidCallback? onDiscardTap;
  final ValueChanged<CardId>? onHandCardTap;
  final void Function(int ownerIndex, int meldIndex)? onMeldTap;

  final Map<CardId, CardSprite> _sprites = {};
  bool _placed = false;

  double _cardH = 72;
  double _cardW = 49;

  @override
  Color backgroundColor() => const Color(0xFF0A1F1A);

  @override
  Future<void> onLoad() async {
    for (var id = 0; id < 52; id++) {
      final sprite = CardSprite(id);
      _sprites[id] = sprite;
      await add(sprite);
    }
  }

  void handleCardTap(CardSprite sprite) {
    switch (sprite.zone) {
      case CardZone.stock:
        onStockTap?.call();
      case CardZone.discard:
        onDiscardTap?.call();
      case CardZone.hand:
        onHandCardTap?.call(sprite.cardId);
      case CardZone.meld:
        onMeldTap?.call(sprite.ownerIndex, sprite.meldIndex);
      case CardZone.opponentHand:
        break;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_sprites.length < 52 || size.x < 10 || size.y < 10) return;
    _layout(dt);
  }

  void _layout(double dt) {
    final w = size.x;
    final h = size.y;
    _cardH = (h * 0.2).clamp(54.0, 100.0).toDouble();
    _cardW = _cardH * 0.68;

    final targets = <CardId, _Target>{};
    final stockPos = Vector2(w * 0.44, h * 0.40);
    final discardPos = Vector2(w * 0.56, h * 0.40);

    // Stock and discard piles.
    for (var i = 0; i < game.stock.length; i++) {
      targets[game.stock[i]] = _Target(stockPos, 1, i, false, CardZone.stock);
    }
    for (var i = 0; i < game.discardPile.length; i++) {
      targets[game.discardPile[i]] = _Target(
        discardPos,
        1,
        100 + i,
        true,
        CardZone.discard,
      );
    }

    // Your hand: an upright overlapped row along the bottom.
    final mine = game.players[0].hand;
    if (mine.isNotEmpty) {
      final available = w * 0.62;
      final step = mine.length == 1
          ? 0.0
          : math.min(_cardW * 0.9, (available - _cardW) / (mine.length - 1));
      final total = step * (mine.length - 1);
      final y = h - _cardH / 2 - 6;
      for (var i = 0; i < mine.length; i++) {
        final isSelected = selected.contains(mine[i]);
        targets[mine[i]] = _Target(
          Vector2(
            w * 0.5 - total / 2 + i * step,
            y - (isSelected ? _cardH * 0.22 : 0),
          ),
          1,
          400 + i,
          true,
          CardZone.hand,
          selected: isSelected,
        );
      }
    }

    // Opponent hands: small face-down stacks on the left and right edges.
    for (var p = 1; p <= 2; p++) {
      final hand = game.players[p].hand;
      final x = p == 1 ? w * 0.075 : w * 0.925;
      for (var i = 0; i < hand.length; i++) {
        targets[hand[i]] = _Target(
          Vector2(x, h * 0.34 + _cardH * 0.31 + i * 8),
          0.62,
          300 + i,
          false,
          CardZone.opponentHand,
          ownerIndex: p,
        );
      }
    }

    // Melds, shown small and face up beside each seat.
    _placeMelds(targets, 0, left: w * 0.22, top: h * 0.58, maxWidth: w * 0.56);
    _placeMelds(targets, 1, left: w * 0.22, top: h * 0.12, maxWidth: w * 0.19);
    _placeMelds(targets, 2, left: w * 0.60, top: h * 0.12, maxWidth: w * 0.17);

    // Ease every card toward its target spot.
    final t = 1 - math.exp(-dt * 14);
    for (final entry in targets.entries) {
      final sprite = _sprites[entry.key]!;
      final target = entry.value;

      if (!_placed) {
        sprite.position.setValues(stockPos.x, stockPos.y);
        sprite.size.setValues(_cardW, _cardH);
      }

      sprite.position.x += (target.position.x - sprite.position.x) * t;
      sprite.position.y += (target.position.y - sprite.position.y) * t;
      sprite.size.x += (_cardW * target.scale - sprite.size.x) * t;
      sprite.size.y += (_cardH * target.scale - sprite.size.y) * t;

      sprite
        ..faceUp = target.faceUp
        ..selected = target.selected
        ..zone = target.zone
        ..ownerIndex = target.ownerIndex
        ..meldIndex = target.meldIndex;
      if (sprite.priority != target.priority) sprite.priority = target.priority;
    }
    _placed = true;
  }

  void _placeMelds(
    Map<CardId, _Target> targets,
    int player, {
    required double left,
    required double top,
    required double maxWidth,
  }) {
    const scale = 0.5;
    final mw = _cardW * scale;
    final mh = _cardH * scale;
    final overlap = mw * 0.55;
    const gap = 8.0;

    var x = 0.0;
    var row = 0;
    var order = 0;
    final melds = game.players[player].melds;

    for (var m = 0; m < melds.length; m++) {
      final cards = melds[m].cards;
      final width = mw + (cards.length - 1) * overlap;
      if (x > 0 && x + width > maxWidth) {
        x = 0;
        row++;
      }
      for (var i = 0; i < cards.length; i++) {
        targets[cards[i]] = _Target(
          Vector2(left + x + mw / 2 + i * overlap, top + mh / 2 + row * (mh + 4)),
          scale,
          200 + order++,
          true,
          CardZone.meld,
          ownerIndex: player,
          meldIndex: m,
        );
      }
      x += width + gap;
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final bounds = Rect.fromLTWH(0, 0, w, h);

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF174B38), Color(0xFF0D2B23), Color(0xFF081B17)],
        ).createShader(bounds),
    );

    final felt = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.04, h * 0.05, w * 0.92, h * 0.80),
      Radius.circular(h * 0.4),
    );
    canvas.drawRRect(felt.inflate(7), Paint()..color = const Color(0xFF5A3A22));
    canvas.drawRRect(felt, Paint()..color = const Color(0xFF185447));
    canvas.drawRRect(
      felt.deflate(10),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x33FFFFFF),
    );

    // Empty-pile outlines.
    final slot = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x55FFFFFF);
    for (final center in [Offset(w * 0.44, h * 0.40), Offset(w * 0.56, h * 0.40)]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: _cardW, height: _cardH),
          const Radius.circular(8),
        ),
        slot,
      );
    }

    super.render(canvas);
  }
}

class _Target {
  _Target(
    this.position,
    this.scale,
    this.priority,
    this.faceUp,
    this.zone, {
    this.ownerIndex = 0,
    this.meldIndex = 0,
    this.selected = false,
  });

  final Vector2 position;
  final double scale;
  final int priority;
  final bool faceUp;
  final CardZone zone;
  final int ownerIndex;
  final int meldIndex;
  final bool selected;
}

/// One playing card, drawn in code (no image assets).
class CardSprite extends PositionComponent
    with TapCallbacks, HasGameReference<TongitsTableGame> {
  CardSprite(this.cardId)
    : super(size: Vector2(_baseW, _baseH), anchor: Anchor.center);

  static const double _baseW = 68;
  static const double _baseH = 100;

  final CardId cardId;

  bool faceUp = false;
  bool selected = false;
  CardZone zone = CardZone.stock;
  int ownerIndex = 0;
  int meldIndex = 0;

  late final PlayingCard _card = PlayingCard(cardId);
  late final Color _ink =
      (_card.suit == Suit.hearts || _card.suit == Suit.diamonds)
      ? const Color(0xFFB3261E)
      : const Color(0xFF17211D);
  late final TextPainter _rank = _painter(_card.rankLabel, 19, FontWeight.w800);
  late final TextPainter _smallSuit = _painter(_card.suitSymbol, 15, FontWeight.w600);
  late final TextPainter _bigSuit = _painter(_card.suitSymbol, 40, FontWeight.w600);

  static final Paint _shadow = Paint()..color = const Color(0x55000000);
  static final Paint _face = Paint()..color = const Color(0xFFFFFDF7);
  static final Paint _back = Paint()..color = const Color(0xFF1B3A6B);

  TextPainter _painter(String text, double fontSize, FontWeight weight) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _ink,
          fontSize: fontSize,
          fontWeight: weight,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void onTapUp(TapUpEvent event) => game.handleCardTap(this);

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.scale(size.x / _baseW, size.y / _baseH);

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, _baseW, _baseH),
      const Radius.circular(9),
    );
    canvas.drawRRect(body.shift(const Offset(0, 2.5)), _shadow);

    if (faceUp) {
      canvas.drawRRect(body, _face);
      canvas.drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 3.5 : 1.5
          ..color = selected
              ? const Color(0xFFFFD166)
              : const Color(0xFFD9AD55),
      );
      _rank.paint(canvas, const Offset(7, 6));
      _smallSuit.paint(canvas, const Offset(7, 27));
      _bigSuit.paint(
        canvas,
        Offset(
          (_baseW - _bigSuit.width) / 2 + 4,
          (_baseH - _bigSuit.height) / 2 + 12,
        ),
      );
    } else {
      canvas.drawRRect(body, _back);
      canvas.drawRRect(
        body.deflate(6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFB8C4E0),
      );
      canvas.drawCircle(
        const Offset(_baseW / 2, _baseH / 2),
        12,
        Paint()..color = const Color(0x55B8C4E0),
      );
    }

    canvas.restore();
  }
}