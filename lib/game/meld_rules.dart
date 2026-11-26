import 'card.dart';

enum MeldKind { set, run }

/// Returns the kind of meld [cards] form, or null if they are not a valid
/// set (3-4 cards of one rank) or run (3+ consecutive cards of one suit,
/// Ace low only).
MeldKind? classifyMeld(List<CardId> cards) {
  if (cards.length < 3 || cards.toSet().length != cards.length) return null;

  final parsed = cards.map(PlayingCard.new).toList();
  final firstRank = parsed.first.rank;

  if (parsed.every((card) => card.rank == firstRank)) {
    return cards.length <= 4 ? MeldKind.set : null;
  }

  final suit = parsed.first.suit;
  if (parsed.any((card) => card.suit != suit)) return null;

  final ranks = parsed.map((card) => card.rank).toList()..sort();
  for (var i = 1; i < ranks.length; i++) {
    if (ranks[i] != ranks[i - 1] + 1) return null;
  }
  return MeldKind.run;
}

/// Sorts [cards] in place for display: runs by rank, sets by suit.
void sortMeldCards(List<CardId> cards, MeldKind kind) {
  if (kind == MeldKind.run) {
    cards.sort(
      (a, b) => PlayingCard(a).rank.compareTo(PlayingCard(b).rank),
    );
  } else {
    cards.sort(
      (a, b) => PlayingCard(a).suit.index.compareTo(PlayingCard(b).suit.index),
    );
  }
}

int meldPoints(List<CardId> cards) =>
    cards.fold(0, (sum, id) => sum + PlayingCard(id).deadwoodValue);

/// True if [card] could be melded immediately together with cards in [hand].
bool canFormMeldWith(CardId card, List<CardId> hand) =>
    findBestMelds([...hand, card], mustInclude: card).isNotEmpty;

/// Finds the set of non-overlapping melds in [hand] that removes the most
/// points from the hand. If [mustInclude] is given, the result must contain
/// that card (an empty list means it cannot be melded).
List<List<CardId>> findBestMelds(List<CardId> hand, {CardId? mustInclude}) {
  final candidates = _candidateMelds(hand);
  var best = <List<CardId>>[];
  var bestScore = -1;

  void search(
    int start,
    Set<CardId> used,
    List<List<CardId>> chosen,
    int score,
  ) {
    final satisfied = mustInclude == null || used.contains(mustInclude);
    if (satisfied && score > bestScore) {
      bestScore = score;
      best = [for (final meld in chosen) List<CardId>.of(meld)];
    }

    for (var i = start; i < candidates.length; i++) {
      final candidate = candidates[i];
      if (candidate.any(used.contains)) continue;

      used.addAll(candidate);
      chosen.add(candidate);
      search(i + 1, used, chosen, score + meldPoints(candidate));
      chosen.removeLast();
      used.removeAll(candidate);
    }
  }

  search(0, <CardId>{}, <List<CardId>>[], 0);
  return best;
}

List<List<CardId>> _candidateMelds(List<CardId> hand) {
  final result = <List<CardId>>[];
  final byRank = <int, List<CardId>>{};
  final bySuit = <Suit, Map<int, CardId>>{};

  for (final id in hand) {
    final card = PlayingCard(id);
    byRank.putIfAbsent(card.rank, () => <CardId>[]).add(id);
    bySuit.putIfAbsent(card.suit, () => <int, CardId>{})[card.rank] = id;
  }

  // Sets: all matching cards, plus every 3-card subset of a four of a kind
  // (so one card can be spared for a run).
  for (final cards in byRank.values) {
    if (cards.length < 3) continue;
    result.add(List<CardId>.of(cards));
    if (cards.length == 4) {
      for (var skip = 0; skip < 4; skip++) {
        result.add([
          for (var i = 0; i < 4; i++)
            if (i != skip) cards[i],
        ]);
      }
    }
  }

  // Runs: every consecutive stretch of 3+ ranks within a suit.
  for (final ranks in bySuit.values) {
    final sorted = ranks.keys.toList()..sort();
    for (var start = 0; start < sorted.length; start++) {
      var end = start;
      while (end + 1 < sorted.length && sorted[end + 1] == sorted[end] + 1) {
        end++;
      }
      for (var stop = start + 2; stop <= end; stop++) {
        result.add([
          for (var i = start; i <= stop; i++) ranks[sorted[i]]!,
        ]);
      }
    }
  }

  return result;
}