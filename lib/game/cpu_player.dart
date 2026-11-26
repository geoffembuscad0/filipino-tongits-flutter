import 'card.dart';
import 'game_state.dart';
import 'meld_rules.dart';

/// A card the CPU can add to an already exposed meld.
class LayOffMove {
  const LayOffMove(this.card, this.ownerIndex, this.meldIndex);

  final CardId card;
  final int ownerIndex;
  final int meldIndex;
}

class CpuPlayer {
  /// Plays a whole turn instantly (tests and simple callers).
  void playTurn(GameState game) {
    _assertCpuTurn(game);

    if (game.phase == TurnPhase.draw) drawStep(game);
    if (game.phase != TurnPhase.discard) return;

    for (final meld in planMelds(game)) {
      game.layMeld(meld);
      if (game.phase != TurnPhase.discard) return;
    }

    while (game.phase == TurnPhase.discard) {
      final move = nextLayOff(game);
      if (move == null) break;
      game.layOff(move.card, move.ownerIndex, move.meldIndex);
    }

    if (game.phase == TurnPhase.discard) discardStep(game);
  }

  /// Guaranteed-valid way to end the turn right now (used when the 15 second
  /// budget runs out). Does every *required* action and skips optional ones:
  /// draw if the turn hasn't drawn yet, resolve a card taken from the
  /// discard pile, then discard.
  void finishTurnNow(GameState game) {
    _assertCpuTurn(game);

    if (game.phase == TurnPhase.draw) drawStep(game);
    if (game.phase != TurnPhase.discard) return;

    _resolvePendingDiscard(game);
    if (game.phase == TurnPhase.discard) discardStep(game);
  }

  /// Draws a card. Returns true if it was taken from the discard pile.
  bool drawStep(GameState game) {
    _assertCpuTurn(game);
    if (game.phase != TurnPhase.draw) {
      throw StateError('CPU can only draw during the draw phase.');
    }

    if (game.canDrawFromDiscard) {
      game.drawFromDiscard();
      return true;
    }
    game.drawFromStock(); // Ends the round if the stock is empty.
    return false;
  }

  /// Melds worth laying down right now. A card taken from the discard pile
  /// is always included when a meld with it exists.
  List<List<CardId>> planMelds(GameState game) {
    final hand = game.currentPlayer.hand;
    final pending = game.pendingDiscardCard;

    if (pending != null) {
      final withPending = findBestMelds(hand, mustInclude: pending);
      if (withPending.isNotEmpty) return withPending;
    }
    return findBestMelds(hand);
  }

  /// The next card that can be added to any exposed meld, if any.
  LayOffMove? nextLayOff(GameState game) {
    final hand = game.currentPlayer.hand;
    final pending = game.pendingDiscardCard;
    final ordered = <CardId>[
      if (pending != null && hand.contains(pending)) pending,
      ...hand.where((id) => id != pending),
    ];

    for (final card in ordered) {
      for (var owner = 0; owner < game.players.length; owner++) {
        final melds = game.players[owner].melds;
        for (var i = 0; i < melds.length; i++) {
          if (game.canLayOff(card, owner, i)) {
            return LayOffMove(card, owner, i);
          }
        }
      }
    }
    return null;
  }

  CardId discardStep(GameState game) {
    _assertCpuTurn(game);
    final card = _chooseDiscard(game.currentPlayer.hand, game);
    game.discardFromHand(card);
    return card;
  }

  void _resolvePendingDiscard(GameState game) {
    while (game.pendingDiscardCard != null &&
        game.phase == TurnPhase.discard) {
      final pending = game.pendingDiscardCard!;
      final containing = planMelds(game).where((m) => m.contains(pending));

      if (containing.isNotEmpty) {
        game.layMeld(containing.first);
        continue;
      }

      final move = nextLayOff(game);
      if (move == null) {
        throw StateError('Discard-pile card cannot be used; rules violated.');
      }
      game.layOff(move.card, move.ownerIndex, move.meldIndex);
    }
  }

  void _assertCpuTurn(GameState game) {
    if (!game.currentPlayer.isCpu) {
      throw StateError('It is not a CPU player’s turn.');
    }
    if (game.phase == TurnPhase.roundOver) {
      throw StateError('The round is over.');
    }
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