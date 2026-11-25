import 'dart:math';

import 'package:flutter/material.dart';

import 'package:flutter_tongits_offline/game/card.dart';
import 'package:flutter_tongits_offline/game/deal_cards.dart';
import 'package:flutter_tongits_offline/game/game_state.dart';
import 'package:flutter_tongits_offline/game/jack_en_poy.dart';

class JackEnPoyScreen extends StatefulWidget {
  const JackEnPoyScreen({super.key, Random? random}) : _random = random;

  final Random? _random;

  @override
  State<JackEnPoyScreen> createState() => _JackEnPoyScreenState();
}

class _JackEnPoyScreenState extends State<JackEnPoyScreen> {
  late final Random _random = widget._random ?? Random();

  JackEnPoyResult? _result;
  GameState? _game;

  void _play(RpsChoice choice) {
    setState(() {
      _result = JackEnPoyGame(random: _random).play(choice);
    });
  }

  void _dealCards() {
    final result = _result;
    if (result == null) return;

    setState(() {
      _game = dealNewGame(
        players: createDefaultPlayers(),
        firstPlayerIndex: result.winnerIndex,
        random: _random,
      );
    });
  }

  void _playAgain() {
    setState(() {
      _result = null;
      _game = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final game = _game;

    return Scaffold(
      appBar: AppBar(title: const Text('Jack-en-Poy')),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF174B38), Color(0xFF0D2B23), Color(0xFF081B17)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                game == null ? 'Who goes first?' : 'Cards are dealt!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFFF1D58A),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                game == null
                    ? 'Choose Rock, Paper, or Scissors to decide who draws first.'
                    : 'The Jack-en-Poy winner takes the first turn.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (result == null) ...[
                const _PlayerBadge(name: 'You', icon: Icons.person),
                const SizedBox(height: 12),
                const _PlayerBadge(
                  name: 'CPU Player 1',
                  icon: Icons.smart_toy_outlined,
                ),
                const SizedBox(height: 12),
                const _PlayerBadge(
                  name: 'CPU Player 2',
                  icon: Icons.smart_toy_outlined,
                ),
                const SizedBox(height: 24),
                const Text(
                  'The CPUs have a 60% combined chance to win this opening.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFF1D58A)),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final choice in RpsChoice.values)
                      FilledButton.tonalIcon(
                        onPressed: () => _play(choice),
                        icon: Text(choice.symbol),
                        label: Text(choice.label),
                      ),
                  ],
                ),
              ] else ...[
                Card(
                  color: const Color(0xFF12392E),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (var index = 0; index < result.choices.length; index++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(_playerName(index)),
                                ),
                                Text(
                                  '${result.choices[index].symbol} '
                                  '${result.choices[index].label}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (index == result.winnerIndex) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.emoji_events,
                                    color: Color(0xFFD9AD55),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${_playerName(result.winnerIndex)} wins the opening!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF1D58A),
                  ),
                ),
                const SizedBox(height: 20),
                if (game == null)
                  FilledButton.icon(
                    onPressed: _dealCards,
                    icon: const Icon(Icons.style),
                    label: const Text('DEAL CARDS'),
                  )
                else ...[
                  _DealtGameSummary(game: game),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _playAgain,
                    icon: const Icon(Icons.refresh),
                    label: const Text('NEW ROUND'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _playerName(int index) => switch (index) {
    0 => 'You',
    1 => 'CPU Player 1',
    2 => 'CPU Player 2',
    _ => throw RangeError.index(index, const [0, 1, 2]),
  };
}

class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge({required this.name, required this.icon});

  final String name;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF12392E),
      child: ListTile(leading: Icon(icon), title: Text(name)),
    );
  }
}

class _DealtGameSummary extends StatelessWidget {
  const _DealtGameSummary({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF12392E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'First to draw: ${game.currentPlayer.name}',
              style: const TextStyle(
                color: Color(0xFFF1D58A),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            for (final player in game.players)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  player.isCpu
                      ? '${player.name}: ${player.hand.length} cards'
                      : '${player.name}: ${player.hand.length} cards',
                ),
              ),
            const SizedBox(height: 4),
            Text('${game.stock.length} cards remain in the stock.'),
            const SizedBox(height: 16),
            const Text('Your hand'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final cardId in game.players.first.hand)
                  Chip(label: Text(PlayingCard(cardId).toString())),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
