import 'dart:math';

/// The player's Jack-en-Poy selection.
enum RpsChoice { rock, paper, scissors }

extension RpsChoiceRules on RpsChoice {
  String get label => switch (this) {
    RpsChoice.rock => 'Rock',
    RpsChoice.paper => 'Paper',
    RpsChoice.scissors => 'Scissors',
  };

  String get symbol => switch (this) {
    RpsChoice.rock => '✊',
    RpsChoice.paper => '✋',
    RpsChoice.scissors => '✌️',
  };

  /// The hand this choice defeats.
  RpsChoice get defeats => switch (this) {
    RpsChoice.rock => RpsChoice.scissors,
    RpsChoice.paper => RpsChoice.rock,
    RpsChoice.scissors => RpsChoice.paper,
  };

  /// The hand that defeats this choice.
  RpsChoice get defeatedBy => switch (this) {
    RpsChoice.rock => RpsChoice.paper,
    RpsChoice.paper => RpsChoice.scissors,
    RpsChoice.scissors => RpsChoice.rock,
  };
}

class JackEnPoyResult {
  const JackEnPoyResult({
    required this.choices,
    required this.winnerIndex,
  });

  /// Choices are in game player order: You, CPU Player 1, CPU Player 2.
  final List<RpsChoice> choices;
  final int winnerIndex;
}

/// Determines the opening player. The CPU side has a configurable chance of
/// winning the opening; default is 60%, as requested for this game.
///
/// Choices are generated after the human chooses and match the resolved
/// outcome, so the odds are intentionally weighted rather than independent,
/// fair RPS. The displayed choices still form a valid decisive RPS result.
class JackEnPoyGame {
  JackEnPoyGame({
    Random? random,
    this.cpuWinProbability = 0.6,
  }) : _random = random ?? Random() {
    if (cpuWinProbability < 0 || cpuWinProbability > 1) {
      throw ArgumentError.value(
        cpuWinProbability,
        'cpuWinProbability',
        'Must be between 0 and 1.',
      );
    }
  }

  final Random _random;
  final double cpuWinProbability;

  JackEnPoyResult play(RpsChoice humanChoice) {
    final cpuSideWins = _random.nextDouble() < cpuWinProbability;

    if (!cpuSideWins) {
      final losingChoice = humanChoice.defeats;
      return JackEnPoyResult(
        choices: [humanChoice, losingChoice, losingChoice],
        winnerIndex: 0,
      );
    }

    // Pick which CPU wins. The other CPU chooses the human's hand, so the
    // selected CPU's winning hand beats both opponents' choices.
    final winnerIndex = _random.nextInt(2) + 1;
    final cpuWinningChoice = humanChoice.defeatedBy;
    final choices = List<RpsChoice>.filled(3, humanChoice);
    choices[winnerIndex] = cpuWinningChoice;

    return JackEnPoyResult(choices: choices, winnerIndex: winnerIndex);
  }
}
