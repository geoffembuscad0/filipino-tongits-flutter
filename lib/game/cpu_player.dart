import 'card.dart';
import 'game_state.dart';

class CpuPlayer {
  void playTurn(GameState game) {
    final player = game.currentPlayer;

    if (!player.isCpu) {
      throw StateError('It is not a CPU player’s turn.');
    }
    if (game.phase != TurnPhase.draw) {
      throw StateError('CPU turn must start in the draw phase.');
    }

    // Prefer the visible discard if it may help form a set or run.
    if (game.discardPile.isNotEmpty &&
        _connectionStrength(game.discardPile.last, player.hand) >= 2) {
      game.drawFromDiscard();
    } else {
      final drawnCard = game.drawFromStock();

      // Stock is empty and the round has ended.
      if (drawnCard == null) return;
    }

    final cardToDiscard = _chooseDiscard(player.hand, game);
    game.discardFromHand(cardToDiscard);
  }

  CardId _chooseDiscard(List<CardId> hand, GameState game) {
    var highestDiscardCost = -1 << 30;
    final bestCandidates = <CardId>[];

    for (final candidate in hand) {
      final card = PlayingCard(candidate);
      final connections = _connectionStrength(
        candidate,
        hand.where((id) => id != candidate).toList(),
      );

      // Prefer discarding high-value cards that have few potential connections.
      final discardCost = card.deadwoodValue * 10 - connections * 4;

      if (discardCost > highestDiscardCost) {
        highestDiscardCost = discardCost;
        bestCandidates
          ..clear()
          ..add(candidate);
      } else if (discardCost == highestDiscardCost) {
        bestCandidates.add(candidate);
      }
    }

    return bestCandidates[game.random.nextInt(bestCandidates.length)];
  }

  int _connectionStrength(CardId cardId, List<CardId> otherCards) {
    final card = PlayingCard(cardId);
    var strength = 0;

    for (final otherId in otherCards) {
      final other = PlayingCard(otherId);

      if (card.rank == other.rank) {
        // Same rank may contribute to a set.
        strength += 3;
      } else if (card.suit == other.suit) {
        final distance = (card.rank - other.rank).abs();

        if (distance == 1) {
          strength += 2;
        } else if (distance == 2) {
          strength += 1;
        }
      }
    }

    return strength;
  }
}
