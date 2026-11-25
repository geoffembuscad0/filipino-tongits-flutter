import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:flutter_tongits_offline/game/deal_cards.dart';
import 'package:flutter_tongits_offline/game/game_state.dart';
import 'package:flutter_tongits_offline/table/tongits_table.dart';

/// Watch three CPU players play a full round on the animated table.
class CpuDemoScreen extends StatefulWidget {
  const CpuDemoScreen({super.key, this.seed});

  /// Fixes the shuffle, handy for repeating the same round while tuning.
  final int? seed;

  @override
  State<CpuDemoScreen> createState() => _CpuDemoScreenState();
}

class _CpuDemoScreenState extends State<CpuDemoScreen> {
  int _round = 0;
  late TongitsTable _table = _createTable();

  TongitsTable _createTable() {
    final random = widget.seed == null ? Random() : Random(widget.seed! + _round);
    final players = [
      PlayerState(name: 'CPU Alpha', isCpu: true),
      PlayerState(name: 'CPU Beta', isCpu: true),
      PlayerState(name: 'CPU Gamma', isCpu: true),
    ];
    final game = dealNewGame(
      players: players,
      firstPlayerIndex: random.nextInt(players.length),
      random: random,
    );
    return TongitsTable(state: game);
  }

  void _newRound() {
    setState(() {
      _round++;
      _table = _createTable();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CPU Demo')),
      body: SafeArea(
        child: GameWidget<TongitsTable>(key: ValueKey(_round), game: _table),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newRound,
        icon: const Icon(Icons.refresh),
        label: const Text('NEW ROUND'),
      ),
    );
  }
}