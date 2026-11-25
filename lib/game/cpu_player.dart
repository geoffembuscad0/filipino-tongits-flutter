import 'card.dart';
import 'game_state.dart';

class CpuPlayer {
  /// Call Draw when the cards left in hand are worth this many points or fewer.
  static const int drawCallThreshold = 7;

  /// Accept a Draw challenge when the cards in hand are worth this or fewer.
  static const int fightThreshold = 9;

  /// Plays one full CPU turn: draw (or call Draw), expose melds, lay off
  /// cards, then discard. Returns early if the round ends along the way.
  void playTurn(GameState game) {
    final player = game.currentPlayer;

    if (!player.isCpu) {
      throw StateError('It is not a CPU player’s turn.');
    }
    if (game.isRoundOver) return;

    if (game.phase == TurnPhase.draw) {
      if (_shouldCallDraw(player)) {
        game.callDraw();
        respondToChallenges(game);
        return;
      }
      if (!_draw(game, player)) return; // Stock ran out; round is over.
      if (game.isRoundOver) return;
    }

    if (game.phase != TurnPhase.play) {
      throw StateError('CPU cannot play during ${game.phase}.');
    }

    _exposeMelds(game, player);
    if (game.isRoundOver) return;

    _layOffCards(game, player);
    if (game.isRoundOver) return;

    game.discardFromHand(_chooseDiscard(player.hand, game));
  }

  /// Answers a Draw challenge for every CPU that has not responded yet.
  /// A human player's response must be recorded separately by the UI.
  void respondToChallenges(GameState game) {
    for (final index in game.pendingChallengeResponders) {
      final player = game.players[index];
      if (!player.isCpu) continue;

      game.respondToChallenge(
        index,
        fight: deadwoodTotal(player.hand) <= fightThreshold,
      );
    }
  }

  bool _shouldCallDraw(PlayerState player) =>
      player.melds.isNotEmpty && deadwoodTotal(player.hand) <= drawCallThreshold;

  /// Returns false if the round ended because the stock was empty.
  bool _draw(GameState game, PlayerState player) {
    // The top discard may only be taken if it completes a meld right away.
    if (game.discardPile.isNotEmpty) {
      final options = meldsUsingCard(game.discardPile.last, player.hand);
      if (options.isNotEmpty) {
        // Prefer the meld that gets rid of the most points.
        options.sort((a, b) => deadwoodTotal(b).compareTo(deadwoodTotal(a)));
        game.drawFromDiscard(options.first);
        return true;
      }
    }

    return game.drawFromStock() != null;
  }

  void _exposeMelds(GameState game, PlayerState player) {
    final plan = planMelds(player.hand);

    for (final meld in plan.melds) {
      game.exposeMeld(meld);
      if (game.isRoundOver) return;
    }
  }

  void _layOffCards(GameState game, PlayerState player) {
    var laidOff = true;

    while (laidOff && !game.isRoundOver) {
      laidOff = false;

      for (final card in List<CardId>.of(player.hand)) {
        final target = _findLayOffTarget(game, card);
        if (target == null) continue;

        game.layOff(card, target);
        laidOff = true;
        break;
      }
    }
  }

  Meld? _findLayOffTarget(GameState game, CardId card) {
    for (final player in game.players) {
      for (final meld in player.melds) {
        if (canLayOff(meld, card)) return meld;
      }
    }
    return null;
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