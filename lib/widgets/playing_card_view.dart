import 'package:flutter/material.dart';
import 'package:flutter_tongits_offline/game/card.dart';

/// Renders one standard playing card upright, with no asset dependency.
class PlayingCardView extends StatelessWidget {
  const PlayingCardView({
    required this.cardId,
    super.key,
    this.width = 68,
    this.height = 100,
    this.isSelected = false,
    this.onTap,
  });

  final CardId cardId;
  final double width;
  final double height;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = PlayingCard(cardId);
    final isRed = card.suit == Suit.hearts || card.suit == Suit.diamonds;
    final ink = isRed ? const Color(0xFFB3261E) : const Color(0xFF17211D);

    return Semantics(
      label: '${card.rankLabel} of ${card.suit.name}',
      button: onTap != null,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: width,
          height: height,
          margin: EdgeInsets.only(top: isSelected ? 0 : 8, bottom: isSelected ? 8 : 0),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF7),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isSelected ? const Color(0xFFFFD166) : const Color(0xFFD9AD55),
              width: isSelected ? 3 : 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
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
                  color: ink,
                  fontSize: 17,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    card.suitSymbol,
                    style: TextStyle(
                      color: ink,
                      fontSize: 34,
                      height: 1,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  card.rankLabel,
                  style: TextStyle(
                    color: ink,
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An upright, horizontally scrollable row of cards for a player's hand.
class PlayerHandView extends StatelessWidget {
  const PlayerHandView({
    required this.cardIds,
    super.key,
    this.selectedCardId,
    this.onCardTap,
  });

  final List<CardId> cardIds;
  final CardId? selectedCardId;
  final ValueChanged<CardId>? onCardTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        itemCount: cardIds.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cardId = cardIds[index];
          return PlayingCardView(
            cardId: cardId,
            isSelected: cardId == selectedCardId,
            onTap: onCardTap == null ? null : () => onCardTap!(cardId),
          );
        },
      ),
    );
  }
}
