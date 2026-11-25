import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../game/card.dart';

/// One persistent visual object per physical card. The same component is
/// repositioned as the card moves between stock, hands, melds and discards.
class CardComponent extends PositionComponent {
  CardComponent(this.cardId)
      : super(
          size: Vector2(54, 78),
          anchor: Anchor.center,
          priority: 0,
        );

  final CardId cardId;
  bool faceUp = false;
  bool selected = false;
  bool travelling = false;

  static const _paper = Color(0xFFFFFDF7);
  static const _ink = Color(0xFF17211D);
  static const _red = Color(0xFFB3261E);
  static const _back = Color(0xFF173F35);
  static const _gold = Color(0xFFD9AD55);

  Future<void> moveTo(
    Vector2 target, {
    double seconds = 0.22,
    double delay = 0,
    Curve curve = Curves.easeInOutCubic,
  }) async {
    travelling = true;
    priority = 100;
    add(
      MoveToEffect(
        target,
        EffectController(
          duration: seconds,
          startDelay: delay,
          curve: curve,
        ),
      ),
    );
    await Future<void>.delayed(
      Duration(milliseconds: ((seconds + delay) * 1000).round()),
    );
    priority = 0;
    travelling = false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(7));

    canvas.drawRRect(
      rrect.shift(const Offset(0, 2)),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    if (!faceUp) {
      canvas.drawRRect(rrect, Paint()..color = _back);
      canvas.drawRRect(
        rrect.deflate(4),
        Paint()
          ..color = _gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      canvas.drawRect(
        rect.deflate(10),
        Paint()
          ..color = const Color(0xFF2B6856)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      return;
    }

    canvas.drawRRect(rrect, Paint()..color = _paper);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = selected ? const Color(0xFFFFC857) : _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 3 : 1,
    );

    final card = PlayingCard(cardId);
    final red = card.suit == Suit.hearts || card.suit == Suit.diamonds;
    final ink = red ? _red : _ink;
    _paintText(canvas, card.rankLabel, Offset(5, 4), 13, ink, true);
    _paintText(canvas, card.suitSymbol, Offset(size.x / 2 - 11, size.y / 2 - 15),
        24, ink, false);
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset,
    double fontSize,
    Color color,
    bool bold,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }
}
