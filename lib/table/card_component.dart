import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import 'package:flutter_tongits_offline/game/card.dart';

/// One playing card on the Flame table. All 52 are created once and travel
/// between zones (stock, hands, melds, discard pile), which is what makes the
/// movement look continuous. Drawn in code, so there are no image assets.
class CardComponent extends PositionComponent {
  CardComponent(this.cardId, {required Vector2 cardSize})
    : card = PlayingCard(cardId),
      super(size: cardSize, anchor: Anchor.center) {
    _buildPainters();
  }

  final CardId cardId;
  final PlayingCard card;

  bool faceUp = false;

  /// Draw order while the card is resting. Flying cards use [_flightPriority].
  int restPriority = 0;

  static const int _flightPriority = 1000;

  static final Paint _shadowPaint = Paint()..color = const Color(0x55000000);
  static final Paint _facePaint = Paint()..color = const Color(0xFFFFFDF7);
  static final Paint _backPaint = Paint()..color = const Color(0xFF1F7665);
  static final Paint _borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = const Color(0xFFD9AD55);
  static final Paint _backInnerPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = const Color(0x99F1D58A);

  late TextPainter _rankTop;
  late TextPainter _suit;
  late TextPainter _rankBottom;

  void resize(Vector2 newSize) {
    if (newSize.x == size.x && newSize.y == size.y) return;
    size = newSize;
    _buildPainters();
  }

  void _buildPainters() {
    final isRed = card.suit == Suit.hearts || card.suit == Suit.diamonds;
    final ink = isRed ? const Color(0xFFB3261E) : const Color(0xFF17211D);

    TextPainter paint(String text, double fontSize, FontWeight weight) {
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: ink,
            fontSize: fontSize,
            height: 1,
            fontWeight: weight,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    _rankTop = paint(card.rankLabel, size.x * 0.26, FontWeight.w800);
    _suit = paint(card.suitSymbol, size.x * 0.5, FontWeight.normal);
    _rankBottom = paint(card.rankLabel, size.x * 0.18, FontWeight.bold);
  }

  /// Places the card instantly, without animation.
  void snapTo(Vector2 target, {required bool faceUp}) {
    position.setFrom(target);
    this.faceUp = faceUp;
    scale.setValues(1, 1);
  }

  /// Slides the card to [target]. The future completes when it arrives.
  Future<void> moveTo(
    Vector2 target, {
    double seconds = 0.4,
    double delay = 0,
    Curve curve = Curves.easeInOutCubic,
  }) {
    final close = (position - target).length2 < 0.25;
    if (close) {
      position.setFrom(target);
      priority = restPriority;
      return Future<void>.value();
    }

    final done = Completer<void>();
    priority = _flightPriority; // draw above everything while travelling
    add(
      MoveToEffect(
        target.clone(),
        EffectController(duration: seconds, startDelay: delay, curve: curve),
        onComplete: () {
          priority = restPriority;
          if (!done.isCompleted) done.complete();
        },
      ),
    );
    return done.future;
  }

  /// Squashes the card flat, swaps the face, and expands it again.
  Future<void> flipTo(
    bool up, {
    double seconds = 0.12,
    double delay = 0,
  }) async {
    if (up == faceUp) return;

    final half = Completer<void>();
    add(
      ScaleEffect.to(
        Vector2(0, 1),
        EffectController(duration: seconds, startDelay: delay),
        onComplete: () => half.complete(),
      ),
    );
    await half.future;

    faceUp = up;

    final done = Completer<void>();
    add(
      ScaleEffect.to(
        Vector2.all(1),
        EffectController(duration: seconds),
        onComplete: () => done.complete(),
      ),
    );
    await done.future;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(w * 0.13),
    );

    canvas.drawRRect(rect.shift(const Offset(0, 2)), _shadowPaint);

    if (faceUp) {
      canvas.drawRRect(rect, _facePaint);
      canvas.drawRRect(rect, _borderPaint);
      _rankTop.paint(canvas, Offset(w * 0.1, h * 0.06));
      _suit.paint(
        canvas,
        Offset((w - _suit.width) / 2, (h - _suit.height) / 2),
      );
      _rankBottom.paint(
        canvas,
        Offset(w - _rankBottom.width - w * 0.1, h - _rankBottom.height - h * 0.06),
      );
    } else {
      canvas.drawRRect(rect, _backPaint);
      canvas.drawRRect(rect, _borderPaint);
      final inner = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, h * 0.09, w * 0.76, h * 0.82),
        Radius.circular(w * 0.08),
      );
      canvas.drawRRect(inner, _backInnerPaint);
    }
  }
}