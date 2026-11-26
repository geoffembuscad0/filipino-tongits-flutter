import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/deal_cards.dart';
import '../game/dice_roll.dart';
import '../game/dice_roll_flame_game.dart';
import '../game/game_state.dart';
import '../widgets/playing_card_view.dart';

class DiceRollScreen extends StatefulWidget {
  const DiceRollScreen({super.key, Random? random}) : _random = random;

  final Random? _random;

  @override
  State<DiceRollScreen> createState() => _DiceRollScreenState();
}

class _DiceRollScreenState extends State<DiceRollScreen> {
  late final Random _random = widget._random ?? Random();
  late final DiceDealerSelection _selection =
      DiceDealerSelection(random: _random);
  late final DiceRollFlameGame _diceGame =
      DiceRollFlameGame(random: _random);

  final Map<int, DiceRollResult> _latestResults = {};
  bool _isRolling = false;
  bool _hasWinner = false;
  int? _dealerIndex;
  GameState? _game;
  String _status = 'Roll two dice to determine the first dealer.';

  static const _playerNames = ['You', 'CPU Player 1', 'CPU Player 2'];

  Future<void> _startRoll() async {
    if (_isRolling) return;

    setState(() {
      _isRolling = true;
      _hasWinner = false;
      _dealerIndex = null;
      _game = null;
      _latestResults.clear();
      _status = 'All three participants are rolling...';
    });

    final winner = await _selection.selectDealer(
      onRoll: (indices, results) async {
        if (!mounted) return;
        setState(() {
          _status = indices.length == 3
              ? 'All participants are rolling...'
              : 'A tie! Only the tied participants roll again.';
        });

        final duration = Duration(
          milliseconds: 2000 + _random.nextInt(2001),
        );
        await _diceGame.animateRoll(
          playerIndices: indices,
          finalResults: results,
          duration: duration,
        );

        if (!mounted) return;
        setState(() {
          for (final result in results) {
            _latestResults[result.playerIndex] = result;
          }
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _dealerIndex = winner;
      _hasWinner = true;
      _isRolling = false;
      _status = '${_playerNames[winner]} is the first dealer!';
    });
  }

  void _dealCards() {
    final dealer = _dealerIndex;
    if (dealer == null) return;

    setState(() {
      _game = dealNewGame(
        players: createDefaultPlayers(),
        firstPlayerIndex: dealer,
        random: _random,
      );
    });
  }

  void _startNewGame() {
    setState(() {
      _latestResults.clear();
      _dealerIndex = null;
      _game = null;
      _hasWinner = false;
      _status = 'Roll two dice to determine the first dealer.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose the First Dealer')),
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
                game == null ? 'LOWEST ROLL DEALS' : 'CARDS ARE DEALT',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFFF1D58A),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 190,
                  child: GameWidget(game: _diceGame),
                ),
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < _playerNames.length; index++)
                _ParticipantResult(
                  name: _playerNames[index],
                  result: _latestResults[index],
                  isDealer: _dealerIndex == index,
                ),
              const SizedBox(height: 18),
              if (!_hasWinner)
                FilledButton.icon(
                  onPressed: _isRolling ? null : _startRoll,
                  icon: const Icon(Icons.casino),
                  label: Text(_isRolling ? 'ROLLING DICE...' : 'ROLL DICE'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD9AD55),
                    foregroundColor: const Color(0xFF17382D),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                )
              else if (game == null)
                FilledButton.icon(
                  onPressed: _dealCards,
                  icon: const Icon(Icons.style),
                  label: const Text('DEAL CARDS'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD9AD55),
                    foregroundColor: const Color(0xFF17382D),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                )
              else ...[
                _DealtGameSummary(game: game),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _startNewGame,
                  icon: const Icon(Icons.refresh),
                  label: const Text('NEW GAME'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantResult extends StatelessWidget {
  const _ParticipantResult({
    required this.name,
    required this.result,
    required this.isDealer,
  });

  final String name;
  final DiceRollResult? result;
  final bool isDealer;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF12392E),
      child: ListTile(
        leading: Icon(
          isDealer ? Icons.emoji_events : Icons.casino_outlined,
          color: isDealer ? const Color(0xFFF1D58A) : Colors.white70,
        ),
        title: Text(name),
        trailing: Text(
          result == null
              ? '—'
              : '${result!.firstDie} + ${result!.secondDie} = ${result!.total}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
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
              'Dealer: ${game.dealer.name}',
              style: const TextStyle(
                color: Color(0xFFF1D58A),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text('First to play: ${game.currentPlayer.name}'),
            const SizedBox(height: 12),
            for (final player in game.players)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${player.name}: ${player.hand.length} cards'),
              ),
            const SizedBox(height: 4),
            Text('${game.stock.length} cards remain in the stock.'),
            const SizedBox(height: 16),
            const Text(
              'Your hand',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            PlayerHandView(cardIds: game.players.first.hand),
          ],
        ),
      ),
    );
  }
}
