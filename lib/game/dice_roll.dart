import 'dart:math';

/// The result of one simultaneous roll by the participants in [playerIndices].
class DiceRollResult {
  const DiceRollResult({
    required this.playerIndex,
    required this.firstDie,
    required this.secondDie,
  });

  final int playerIndex;
  final int firstDie;
  final int secondDie;

  int get total => firstDie + secondDie;
}

/// Pure Dart rules for selecting the first dealer.
///
/// All participants roll two six-sided dice. The lowest total wins.
/// If the lowest total is tied, only those tied participants roll again.
/// The tie-break continues until one participant has the uniquely lowest
/// total within the tied group.
class DiceDealerSelection {
  DiceDealerSelection({Random? random}) : _random = random ?? Random();

  final Random _random;

  List<DiceRollResult> roll(List<int> playerIndices) {
    if (playerIndices.isEmpty) {
      throw ArgumentError('At least one participant must roll.');
    }
    if (playerIndices.toSet().length != playerIndices.length) {
      throw ArgumentError('Participant indices must be unique.');
    }

    return [
      for (final index in playerIndices)
        DiceRollResult(
          playerIndex: index,
          firstDie: _random.nextInt(6) + 1,
          secondDie: _random.nextInt(6) + 1,
        ),
    ];
  }

  /// Returns every player index sharing the lowest total.
  List<int> lowestIndices(List<DiceRollResult> results) {
    if (results.isEmpty) {
      throw ArgumentError('At least one dice result is required.');
    }

    final lowestTotal = results.map((result) => result.total).reduce(min);
    return [
      for (final result in results)
        if (result.total == lowestTotal) result.playerIndex,
    ];
  }

  /// Resolves the dealer. [onRoll] can be used by the UI to animate each roll.
  ///
  /// The first roll includes all three participants. Subsequent rolls include
  /// only participants tied for the lowest total in the preceding roll.
  Future<int> selectDealer({
    required Future<void> Function(
      List<int> playerIndices,
      List<DiceRollResult> results,
    ) onRoll,
    List<int> participantIndices = const [0, 1, 2],
  }) async {
    if (participantIndices.length != 3 ||
        participantIndices.toSet().length != 3) {
      throw ArgumentError('Tongits dealer selection requires three players.');
    }

    var activeIndices = List<int>.of(participantIndices);
    while (true) {
      final results = roll(activeIndices);
      await onRoll(activeIndices, results);
      final lowest = lowestIndices(results);
      if (lowest.length == 1) return lowest.single;
      activeIndices = lowest;
    }
  }
}
