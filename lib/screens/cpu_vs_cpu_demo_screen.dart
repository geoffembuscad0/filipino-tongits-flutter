import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_tongits_offline/components/tongits_table.dart';

class CpuVsCpuDemoScreen extends StatefulWidget {
  const CpuVsCpuDemoScreen({super.key});

  @override
  State<CpuVsCpuDemoScreen> createState() => _CpuVsCpuDemoScreenState();
}

class _CpuVsCpuDemoScreenState extends State<CpuVsCpuDemoScreen> {
  late TongitsTable _table;

  @override
  void initState() {
    super.initState();
    _table = TongitsTable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CPU vs CPU'),
        backgroundColor: const Color(0xFF12392E),
      ),
      body: Container(
        color: const Color(0xFF102522),
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Text(
                  'Animation preview • Watch the engine play a full round',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFE7F0E9)),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: GameWidget(game: _table),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _table = TongitsTable();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('NEW DEMO ROUND'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
