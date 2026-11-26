import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'dice_roll.dart';

/// Flame-rendered dice display. Flutter hosts this game through GameWidget.
class DiceRollFlameGame extends FlameGame {
  DiceRollFlameGame({Random? random}) : _random = random ?? Random();

  final Random _random;
  final List<List<int>> _faces = List.generate(3, (_) => [1, 1]);
  final List<bool> _rolling = [false, false, false];

  List<List<int>> get faces =>
      _faces.map((pair) => List<int>.unmodifiable(pair)).toList();

  double _elapsed = 0;
  double _duration = 0;
  double _changeAccumulator = 0;
  Completer<void>? _rollCompleter;
  List<int> _activeIndices = const [];

  Future<void> animateRoll({
    required List<int> playerIndices,
    required List<DiceRollResult> finalResults,
    required Duration duration,
  }) {
    if (_rollCompleter != null) {
      throw StateError('A dice animation is already running.');
    }
    if (duration < const Duration(seconds: 2) ||
        duration > const Duration(seconds: 4)) {
      throw ArgumentError.value(duration, 'duration', 'Must be 2–4 seconds.');
    }

    _activeIndices = List<int>.of(playerIndices);
    for (final index in _activeIndices) {
      if (index < 0 || index >= 3) {
        throw RangeError.index(index, _faces);
      }
      _rolling[index] = true;
    }

    final finalByPlayer = {
      for (final result in finalResults)
        result.playerIndex: [result.firstDie, result.secondDie],
    };

    _elapsed = 0;
    _duration = duration.inMicroseconds / Duration.microsecondsPerSecond;
    _changeAccumulator = 0;
    final completer = Completer<void>();
    _rollCompleter = completer;

    _pendingFinalFaces = finalByPlayer;
    return completer.future;
  }

  Map<int, List<int>> _pendingFinalFaces = {};

  @override
  void update(double dt) {
    super.update(dt);
    final completer = _rollCompleter;
    if (completer == null) return;

    _elapsed += dt;
    _changeAccumulator += dt;

    if (_changeAccumulator >= 0.075 && _elapsed < _duration) {
      _changeAccumulator = 0;
      for (final index in _activeIndices) {
        _faces[index] = [_random.nextInt(6) + 1, _random.nextInt(6) + 1];
      }
    }

    if (_elapsed >= _duration) {
      for (final index in _activeIndices) {
        _faces[index] = List<int>.of(_pendingFinalFaces[index]!);
        _rolling[index] = false;
      }
      _rollCompleter = null;
      _pendingFinalFaces = {};
      _activeIndices = const [];
      completer.complete();
    }
  }

  @override
  Color backgroundColor() => const Color(0xFF12392E);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0 || size.y <= 0) return;

    final panelWidth = size.x * 0.29;
    final gap = size.x * 0.035;
    final totalWidth = panelWidth * 3 + gap * 2;
    final startX = (size.x - totalWidth) / 2;
    final panelTop = size.y * 0.12;
    final panelHeight = size.y * 0.76;
    const names = ['YOU', 'CPU 1', 'CPU 2'];

    for (var player = 0; player < 3; player++) {
      final left = startX + player * (panelWidth + gap);
      final rect = Rect.fromLTWH(left, panelTop, panelWidth, panelHeight);
      final panel = RRect.fromRectAndRadius(
        rect,
        const Radius.circular(14),
      );
      canvas.drawRRect(
        panel,
        Paint()..color = const Color(0xFF1B5141),
      );
      canvas.drawRRect(
        panel,
        Paint()
          ..color = const Color(0xFFB98A43)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      _drawText(
        canvas,
        names[player],
        Offset(left + panelWidth / 2, panelTop + panelHeight * 0.20),
        fontSize: (size.x * 0.035).clamp(10, 16).toDouble(),
        color: const Color(0xFFF1D58A),
        bold: true,
      );

      final dieSize = (panelWidth * 0.32).clamp(22, 52).toDouble();
      final diceGap = panelWidth * 0.06;
      final diceWidth = dieSize * 2 + diceGap;
      final diceLeft = left + (panelWidth - diceWidth) / 2;
      final diceTop = panelTop + panelHeight * 0.36;
      _drawDie(canvas, Offset(diceLeft, diceTop), dieSize, _faces[player][0]);
      _drawDie(
        canvas,
        Offset(diceLeft + dieSize + diceGap, diceTop),
        dieSize,
        _faces[player][1],
      );

      final total = _faces[player][0] + _faces[player][1];
      _drawText(
        canvas,
        _rolling[player] ? 'ROLLING' : 'TOTAL  $total',
        Offset(left + panelWidth / 2, panelTop + panelHeight * 0.78),
        fontSize: (size.x * 0.03).clamp(9, 14).toDouble(),
        color: const Color(0xFFFFFFFF),
        bold: true,
      );
    }
  }

  void _drawDie(Canvas canvas, Offset topLeft, double dieSize, int face) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(topLeft.dx, topLeft.dy, dieSize, dieSize),
      const Radius.circular(7),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xFFFFFDF7));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = const Color(0xFFB98A43)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final positions = <Offset>[
      Offset(0.25, 0.25),
      Offset(0.75, 0.25),
      Offset(0.25, 0.50),
      Offset(0.50, 0.50),
      Offset(0.75, 0.50),
      Offset(0.25, 0.75),
      Offset(0.75, 0.75),
    ];
    final visible = switch (face) {
      1 => [3],
      2 => [0, 6],
      3 => [0, 3, 6],
      4 => [0, 1, 5, 6],
      5 => [0, 1, 3, 5, 6],
      6 => [0, 1, 2, 4, 5, 6],
      _ => const <int>[],
    };
    final dotPaint = Paint()..color = const Color(0xFF18352D);
    for (final positionIndex in visible) {
      final position = positions[positionIndex];
      canvas.drawCircle(
        Offset(
          topLeft.dx + dieSize * position.dx,
          topLeft.dy + dieSize * position.dy,
        ),
        dieSize * 0.065,
        dotPaint,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center, {
    required double fontSize,
    required Color color,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          letterSpacing: 0.6,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: size.x * 0.28);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }
}
