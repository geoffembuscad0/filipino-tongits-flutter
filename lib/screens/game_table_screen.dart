import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_tongits_offline/game/card.dart';
import 'package:flutter_tongits_offline/game/cpu_turn_controller.dart';
import 'package:flutter_tongits_offline/game/game_state.dart';
import 'package:flutter_tongits_offline/game/meld_rules.dart';
import 'package:flutter_tongits_offline/game/tongits_table_game.dart';

const _gold = Color(0xFFD9AD55);
const _lightGold = Color(0xFFF1D58A);

/// Landscape table with you at the bottom and the two CPUs on the left and
/// right. The Flame game draws and animates the cards; Flutter widgets on top
/// handle names, CPU countdowns, status text and your action buttons.
class GameTableScreen extends StatefulWidget {
  const GameTableScreen({super.key, required this.game, this.dealerIndex});

  /// A freshly dealt game (see `dealNewGame`).
  final GameState game;

  /// Who dealt (the die-roll winner). Defaults to the first player to act.
  final int? dealerIndex;

  @override
  State<GameTableScreen> createState() => _GameTableScreenState();
}

class _GameTableScreenState extends State<GameTableScreen> {
  late final GameState _game = widget.game;
  late final int _dealerIndex = widget.dealerIndex ?? _game.currentPlayerIndex;
  final Set<CardId> _selected = <CardId>{};

  late final TongitsTableGame _table;
  late final CpuTurnController _cpu;

  bool _sortBySuit = false;
  bool _resultShown = false;
  bool _challengeDialogOpen = false;

  bool get _humanTurn =>
      _game.currentPlayerIndex == 0 && _game.phase != TurnPhase.roundOver;
  bool get _humanDrawing => _humanTurn && _game.phase == TurnPhase.draw;
  bool get _humanActing => _humanTurn && _game.phase == TurnPhase.discard;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _cpu = CpuTurnController(game: _game, onChanged: _afterChange);
    _table = TongitsTableGame(
      game: _game,
      selected: _selected,
      onStockTap: _onStockTap,
      onDiscardTap: _onDiscardTap,
      onHandCardTap: _toggleCard,
      onMeldTap: _onMeldTap,
    );

    final starter = _game.currentPlayer.isCpu
        ? _game.currentPlayer.name
        : 'You';
    _cpu.status.value = '$starter deal${starter == 'You' ? '' : 's'} first '
        'and open${starter == 'You' ? '' : 's'} the round.';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _afterChange();
    });
  }

  @override
  void dispose() {
    _cpu.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ---------------------------------------------------------------- flow

  /// Runs after every state change (yours or a CPU's).
  void _afterChange() {
    if (!mounted) return;

    final hand = _game.players[0].hand;
    _selected.removeWhere((id) => !hand.contains(id));
    setState(() {});

    if (_game.phase == TurnPhase.roundOver) {
      _showResult();
      return;
    }
    if (_game.phase == TurnPhase.challenge) {
      _handleChallenge();
      return;
    }
    if (_game.currentPlayer.isCpu) unawaited(_cpu.startTurn());
  }

  /// A Draw was called: CPUs answer on their own, you answer with a dialog.
  void _handleChallenge() {
    unawaited(_cpu.runChallengeResponses());
    if (_game.pendingChallengeResponders.contains(0)) _showChallengeDialog();
  }

  void _say(String message) => _cpu.status.value = message;

  // ------------------------------------------------------- human actions

  void _onStockTap() {
    if (!_humanDrawing) return;
    _selected.clear();
    _game.drawFromStock();
    _say('You drew from the stock');
    _afterChange();
  }

  void _onDiscardTap() {
    if (_humanDrawing) {
      if (!_game.canDrawFromDiscard) {
        _say('You can only take the discard if you can use it right away.');
        setState(() {});
        return;
      }
      final card = _game.drawFromDiscard();
      _selected
        ..clear()
        ..addAll(_suggestedMeldWith(card));
      _say('You took ${PlayingCard(card)} - meld it or lay it off');
      _afterChange();
    } else if (_humanActing) {
      _discardSelected();
    }
  }

  Set<CardId> _suggestedMeldWith(CardId card) {
    final melds = findBestMelds(_game.players[0].hand, mustInclude: card);
    for (final meld in melds) {
      if (meld.contains(card)) return meld.toSet();
    }
    return <CardId>{};
  }

  void _toggleCard(CardId id) {
    if (!_humanActing) return;
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  bool get _canMeld => _humanActing && classifyMeld(_selected.toList()) != null;

  bool get _canDiscard =>
      _humanActing &&
      _selected.length == 1 &&
      _game.pendingDiscardCard == null;

  void _meldSelected() {
    if (!_canMeld) return;
    final meld = _game.layMeld(_selected.toList());
    _selected.clear();
    _say('You laid down a ${meld.kind.name}');
    _afterChange();
  }

  void _discardSelected() {
    if (!_canDiscard) return;
    final card = _selected.single;
    _selected.clear();
    _game.discardFromHand(card);
    _say('You discarded ${PlayingCard(card)}');
    _afterChange();
  }

  void _onMeldTap(int ownerIndex, int meldIndex) {
    if (!_humanActing || _selected.length != 1) {
      _say('Select one card, then tap a meld to lay it off.');
      setState(() {});
      return;
    }
    final card = _selected.single;
    if (!_game.canLayOff(card, ownerIndex, meldIndex)) {
      _say('${PlayingCard(card)} does not fit that meld.');
      setState(() {});
      return;
    }
    _selected.clear();
    _game.layOff(card, ownerIndex, meldIndex);
    _say('You laid off ${PlayingCard(card)}');
    _afterChange();
  }

  bool get _canCallDraw => _humanDrawing && _game.canCallDraw;

  void _callDraw() {
    if (!_canCallDraw) return;
    _selected.clear();
    _game.callDraw();
    _say('You called DRAW!');
    _afterChange();
  }

  void _showChallengeDialog() {
    if (_challengeDialogOpen) return;
    _challengeDialogOpen = true;

    final caller = _game.players[_game.challengerIndex!];
    final myPoints = _game.handValue(_game.players[0]);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        void answer(bool fight) {
          Navigator.of(dialogContext).pop();
          _challengeDialogOpen = false;
          if (_game.phase != TurnPhase.challenge) return;
          _game.respondToChallenge(0, fight);
          _say(fight ? 'You chose to FIGHT!' : 'You folded.');
          _afterChange();
        }

        return AlertDialog(
          title: Text('${caller.name} called Draw!'),
          content: Text(
            'Your hand is worth $myPoints points.\n\n'
            'FIGHT: hands are revealed and the lowest total wins. '
            'If you tie with ${caller.name}, you win.\n'
            'FOLD: you lose this round.',
          ),
          actions: [
            TextButton(
              onPressed: () => answer(false),
              child: const Text('FOLD'),
            ),
            FilledButton(
              onPressed: () => answer(true),
              child: const Text('FIGHT'),
            ),
          ],
        );
      },
    );
  }

  void _sortHand() {
    final hand = _game.players[0].hand;
    int bySuit(CardId a, CardId b) {
      final ca = PlayingCard(a);
      final cb = PlayingCard(b);
      final suit = ca.suit.index.compareTo(cb.suit.index);
      return suit != 0 ? suit : ca.rank.compareTo(cb.rank);
    }

    int byRank(CardId a, CardId b) {
      final ca = PlayingCard(a);
      final cb = PlayingCard(b);
      final rank = ca.rank.compareTo(cb.rank);
      return rank != 0 ? rank : ca.suit.index.compareTo(cb.suit.index);
    }

    setState(() {
      hand.sort(_sortBySuit ? bySuit : byRank);
      _sortBySuit = !_sortBySuit;
    });
  }

  // -------------------------------------------------------------- result

  void _showResult() {
    if (_resultShown) return;
    _resultShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(_resultTitle()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_resultReason()),
              const SizedBox(height: 12),
              for (var i = 0; i < _game.players.length; i++)
                Text(
                  '${_game.players[i].name}: '
                  '${_game.handValue(_game.players[i])} points left'
                  '${_resultTag(i)}',
                ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(
              dialogContext,
            ).popUntil((route) => route.isFirst),
              child: const Text('BACK'),
            ),
          ],
        ),
      );
    });
  }

  String _resultTitle() {
    final index = _game.winnerIndex;
    if (index == null) return 'It’s a draw!';
    final player = _game.players[index];
    final who = player.isCpu ? '${player.name} wins' : 'You win';
    return switch (_game.endReason) {
      RoundEndReason.tongits => '$who with Tongits!',
      RoundEndReason.challengeFolded => '$who - everyone folded!',
      RoundEndReason.drawChallenge => '$who the Draw challenge!',
      _ => who,
    };
  }

  String _resultReason() => switch (_game.endReason) {
    RoundEndReason.tongits => 'The winner emptied their hand.',
    RoundEndReason.stockEmpty => 'The stock ran out - lowest hand wins.',
    RoundEndReason.challengeFolded =>
      '${_game.players[_game.challengerIndex!].name} called Draw and '
          'the others folded.',
    RoundEndReason.drawChallenge =>
      'Draw challenge: the lowest hand wins, and a tie goes against the '
          'caller.',
    null => '',
  };

  /// Marks the caller and folders in the showdown list.
  String _resultTag(int index) {
    if (_game.endReason != RoundEndReason.drawChallenge &&
        _game.endReason != RoundEndReason.challengeFolded) {
      return '';
    }
    if (index == _game.challengerIndex) return ' (called Draw)';
    return _game.challengeResponses[index] == false ? ' (folded)' : ' (fought)';
  }

  String get _hint {
    if (_game.phase == TurnPhase.roundOver) return 'Round over';
    if (_game.phase == TurnPhase.challenge) {
      return _game.pendingChallengeResponders.contains(0)
          ? 'Fight or fold?'
          : 'Waiting for the answers…';
    }
    if (!_humanTurn) return '${_game.currentPlayer.name}’s turn…';
    if (_game.phase == TurnPhase.draw) {
      return _game.canCallDraw
          ? 'Draw a card, or call DRAW to challenge.'
          : 'Draw from the stock, or take the discard if it makes a meld.';
    }
    if (_game.pendingDiscardCard != null) {
      return 'Meld or lay off the card you took.';
    }
    return 'Select cards to meld, tap a meld to lay off, or discard one.';
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: GameWidget(game: _table)),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 6,
                  left: 8,
                  child: _OpponentPanel(
                    player: _game.players[1],
                    isActive: _isActive(1),
                    isDealer: _dealerIndex == 1,
                    secondsLeft: _cpu.secondsLeft,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 8,
                  child: _OpponentPanel(
                    player: _game.players[2],
                    isActive: _isActive(2),
                    isDealer: _dealerIndex == 2,
                    secondsLeft: _cpu.secondsLeft,
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 0,
                  right: 0,
                  child: Center(child: _InfoBar(
                    status: _cpu.status,
                    stockCount: _game.stock.length,
                    onBack: () => Navigator.of(context).maybePop(),
                  )),
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: _HumanBadge(
                    isActive: _humanTurn,
                    isDealer: _dealerIndex == 0,
                    hint: _hint,
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: _ActionPanel(
                    onMeld: _canMeld ? _meldSelected : null,
                    onDiscard: _canDiscard ? _discardSelected : null,
                    onCallDraw: _canCallDraw ? _callDraw : null,
                    onSort: _sortHand,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isActive(int index) =>
      _game.phase != TurnPhase.roundOver &&
      _game.phase != TurnPhase.challenge &&
      _game.currentPlayerIndex == index;
}

class _OpponentPanel extends StatelessWidget {
  const _OpponentPanel({
    required this.player,
    required this.isActive,
    required this.isDealer,
    required this.secondsLeft,
  });

  final PlayerState player;
  final bool isActive;
  final bool isDealer;
  final ValueListenable<int> secondsLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? _gold : Colors.white24,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF12392E),
            child: Icon(Icons.smart_toy_outlined, size: 18, color: _lightGold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.style, size: 12, color: Colors.white70),
                    Text(
                      ' ${player.hand.length}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (isDealer) ...[
                      const SizedBox(width: 6),
                      const Text(
                        'DEALER',
                        style: TextStyle(fontSize: 9, color: _lightGold),
                      ),
                    ],
                  ],
                ),
                if (isActive)
                  ValueListenableBuilder<int>(
                    valueListenable: secondsLeft,
                    builder: (context, seconds, _) => Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: seconds <= 5 ? Colors.redAccent : _lightGold,
                        ),
                        Text(
                          ' ${seconds}s',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: seconds <= 5
                                ? Colors.redAccent
                                : _lightGold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBar extends StatelessWidget {
  const _InfoBar({
    required this.status,
    required this.stockCount,
    required this.onBack,
  });

  final ValueListenable<String> status;
  final int stockCount;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0x99000000),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.arrow_back, size: 18),
              onPressed: onBack,
            ),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (context, text, _) => Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: _lightGold),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text('Stock $stockCount', style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _HumanBadge extends StatelessWidget {
  const _HumanBadge({
    required this.isActive,
    required this.isDealer,
    required this.hint,
  });

  final bool isActive;
  final bool isDealer;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? _gold : Colors.white24,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: _lightGold),
              const SizedBox(width: 6),
              const Text(
                'You',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (isDealer) ...[
                const SizedBox(width: 6),
                const Text(
                  'DEALER',
                  style: TextStyle(fontSize: 9, color: _lightGold),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(hint, style: const TextStyle(fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.onMeld,
    required this.onDiscard,
    required this.onCallDraw,
    required this.onSort,
  });

  final VoidCallback? onMeld;
  final VoidCallback? onDiscard;
  final VoidCallback? onCallDraw;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      minimumSize: const Size(96, 30),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      visualDensity: VisualDensity.compact,
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton(
          style: style.copyWith(
            backgroundColor: const WidgetStatePropertyAll(_gold),
            foregroundColor: const WidgetStatePropertyAll(Color(0xFF17382D)),
          ),
          onPressed: onMeld,
          child: const Text('MELD'),
        ),
        const SizedBox(height: 4),
        FilledButton(
          style: style.copyWith(
            backgroundColor: const WidgetStatePropertyAll(Color(0xFF8E2A2A)),
          ),
          onPressed: onDiscard,
          child: const Text('DISCARD'),
        ),
        const SizedBox(height: 4),
        FilledButton(
          style: style.copyWith(
            backgroundColor: const WidgetStatePropertyAll(Color(0xFF2F5D8A)),
          ),
          onPressed: onCallDraw,
          child: const Text('CALL DRAW'),
        ),
        const SizedBox(height: 4),
        FilledButton.tonal(style: style, onPressed: onSort, child: const Text('SORT')),
      ],
    );
  }
}