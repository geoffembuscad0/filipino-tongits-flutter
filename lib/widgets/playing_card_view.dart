import 'package:flutter/material.dart';
import 'package:flutter_tongits_offline/game/card.dart';

class PlayingCardView extends StatelessWidget {
  const PlayingCardView({
    required this.cardId,
    super.key,
    this.onTap,
  });

  final CardId cardId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = PlayingCard(cardId);
    final isRed = card.suit == Suit.hearts || card.suit == Suit.diamonds;
    final cardColor = isRed ? const Color(0xFFB3261E) : const Color(0xFF17211D);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 104,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD9AD55), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.rankLabel,
              style: TextStyle(
                color: cardColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  card.suitSymbol,
                  style: TextStyle(color: cardColor, fontSize: 34),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}