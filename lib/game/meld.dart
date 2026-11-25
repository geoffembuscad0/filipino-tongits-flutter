import 'card.dart';

enum MeldKind { set, run }

class Meld {
  Meld({required List<CardId> cards, required this.kind})
    : cards = (List<CardId>.of(cards)..sort());

  /// Always sorted by card ID. Runs are single-suit, so ID order is rank order.
  final List<CardId> cards;
  final MeldKind kind;

  void add(CardId card) {
    cards
      ..add(card)
      ..sort();
  }
}

/// Total point value of [cards] (Ace = 1, 2–10 = face value, J/Q/K = 10).
int deadwoodTotal(Iterable<CardId> cards) =>
    cards.fold<int>(0, (sum, id) => sum + PlayingCard(id).deadwoodValue);

/// Returns the kind of meld [cards] form, or null if they are not a valid meld.
///
/// - Set: 3 or 4 cards of the same rank.
/// - Run: 3 or more consecutive cards of the same suit. The Ace is low only,
///   so A-2-3 is valid and Q-K-A is not.
MeldKind? classifyMeld(List<CardId> cards) {
  if (cards.length < 3) return null;
  if (cards.toSet().length != cards.length) return null;

  final parsed = cards.map(PlayingCard.new).toList();

  if (cards.length <= 4 && parsed.every((c) => c.rank == parsed.first.rank)) {
    return MeldKind.set;
  }

  if (parsed.every((c) => c.suit == parsed.first.suit)) {
    final ranks = parsed.map((c) => c.rank).toList()..sort();
    for (var i = 1; i < ranks.length; i++) {
      if (ranks[i] != ranks[i - 1] + 1) return null;
    }
    return MeldKind.run;
  }

  return null;
}

/// Whether [card] can be added to an already exposed [meld].
bool canLayOff(Meld meld, CardId card) {
  if (meld.cards.contains(card)) return false;

  final candidate = PlayingCard(card);
  final first = PlayingCard(meld.cards.first);

  switch (meld.kind) {
    case MeldKind.set:
      return meld.cards.length < 4 && candidate.rank == first.rank;
    case MeldKind.run:
      if (candidate.suit != first.suit) return false;
      final lowRank = first.rank;
      final highRank = PlayingCard(meld.cards.last).rank;
      return candidate.rank == lowRank - 1 || candidate.rank == highRank + 1;
  }
}

/// Every valid meld that can be formed from [hand] (overlaps allowed).
List<List<CardId>> candidateMelds(List<CardId> hand) {
  final result = <List<CardId>>[];

  final byRank = <int, List<CardId>>{};
  final bySuit = <Suit, List<CardId>>{};
  for (final id in hand) {
    final card = PlayingCard(id);
    (byRank[card.rank] ??= []).add(id);
    (bySuit[card.suit] ??= []).add(id);
  }

  // Sets: all 3-card combinations, plus the 4-card set.
  for (final group in byRank.values) {
    if (group.length < 3) continue;
    group.sort();
    if (group.length == 4) {
      result.add([...group]);
      for (var skip = 0; skip < 4; skip++) {
        result.add([
          for (var i = 0; i < 4; i++)
            if (i != skip) group[i],
        ]);
      }
    } else {
      result.add([...group]);
    }
  }

  // Runs: every window of 3+ consecutive IDs inside one suit.
  for (final ids in bySuit.values) {
    ids.sort();
    for (var start = 0; start < ids.length; start++) {
      var end = start;
      while (end + 1 < ids.length && ids[end + 1] == ids[end] + 1) {
        end++;
        if (end - start >= 2) result.add(ids.sublist(start, end + 1));
      }
    }
  }

  return result;
}

/// Valid melds that include [card] when it is added to [hand].
/// Used to check whether the top discard may be taken.
List<List<CardId>> meldsUsingCard(CardId card, List<CardId> hand) {
  return candidateMelds([...hand, card])
      .where((meld) => meld.contains(card))
      .toList();
}

class MeldPlan {
  const MeldPlan({required this.melds, required this.deadwood});

  /// Disjoint, valid melds.
  final List<List<CardId>> melds;

  /// Cards left over after [melds].
  final List<CardId> deadwood;

  int get deadwoodValue => deadwoodTotal(deadwood);
}

/// Splits [hand] into disjoint melds so the leftover points are as low as
/// possible. A hand has at most 14 cards, so a simple search is fast enough.
MeldPlan planMelds(List<CardId> hand) {
  final candidates = candidateMelds(hand);
  final total = deadwoodTotal(hand);

  var bestValue = total;
  var bestMelds = <List<CardId>>[];

  void search(
    int start,
    Set<CardId> used,
    List<List<CardId>> chosen,
    int meldedValue,
  ) {
    final remaining = total - meldedValue;
    if (remaining < bestValue) {
      bestValue = remaining;
      bestMelds = [
        for (final meld in chosen) [...meld],
      ];
    }

    for (var i = start; i < candidates.length; i++) {
      final meld = candidates[i];
      if (meld.any(used.contains)) continue;

      used.addAll(meld);
      chosen.add(meld);
      search(i + 1, used, chosen, meldedValue + deadwoodTotal(meld));
      chosen.removeLast();
      used.removeAll(meld);
    }
  }

  search(0, <CardId>{}, <List<CardId>>[], 0);

  final melded = {for (final meld in bestMelds) ...meld};
  return MeldPlan(
    melds: bestMelds,
    deadwood: [
      for (final id in hand)
        if (!melded.contains(id)) id,
    ],
  );
}