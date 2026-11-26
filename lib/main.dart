import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:flutter_tongits_offline/screens/how_to_play_screen.dart';
import 'package:flutter_tongits_offline/screens/dice_roll_screen.dart';

void main() {
  runApp(const TongitsApp());
}

class TongitsApp extends StatelessWidget {
  const TongitsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tongits',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F7665),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF102522),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF174B38),
              Color(0xFF0D2B23),
              Color(0xFF081B17),
            ],
            stops: [0.0, 0.58, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, size: 17),
                        SizedBox(width: 8),
                        Text('OFFLINE CARD GAME'),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'TONGITS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A Filipino classic, wherever you go.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: SizedBox(
                        height: 250,
                        child: GameWidget(game: CardPreviewGame()),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const DiceRollScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('PLAY'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD9AD55),
                        foregroundColor: const Color(0xFF17382D),
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const HowToPlayScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF1D58A),
                        side: const BorderSide(color: Color(0xFFB77A43)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text('HOW TO PLAY'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'You vs. CPU opponents • No internet required',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CardPreviewGame extends FlameGame {
  @override
  Color backgroundColor() => const Color(0xFF185447);

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    _drawCard(
      canvas,
      center: Offset(size.x * 0.30, size.y * 0.52),
      angle: -0.16,
      rank: 'A',
      suit: '♠',
      suitColor: const Color(0xFF18201F),
    );
    _drawCard(
      canvas,
      center: Offset(size.x * 0.50, size.y * 0.48),
      angle: 0,
      rank: '10',
      suit: '♥',
      suitColor: const Color(0xFFC63838),
    );
    _drawCard(
      canvas,
      center: Offset(size.x * 0.70, size.y * 0.52),
      angle: 0.16,
      rank: 'K',
      suit: '♣',
      suitColor: const Color(0xFF18201F),
    );
  }

  void _drawCard(
    Canvas canvas, {
    required Offset center,
    required double angle,
    required String rank,
    required String suit,
    required Color suitColor,
  }) {
    const cardWidth = 94.0;
    const cardHeight = 136.0;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final cardRect = Rect.fromCenter(
      center: Offset.zero,
      width: cardWidth,
      height: cardHeight,
    );
    final card = RRect.fromRectAndRadius(
      cardRect,
      const Radius.circular(10),
    );

    canvas.drawShadow(
      Path()..addRRect(card),
      Colors.black.withValues(alpha: 0.35),
      8,
      true,
    );
    canvas.drawRRect(card, Paint()..color = const Color(0xFFFFFDF7));

    final rankPainter = TextPainter(
      text: TextSpan(
        text: '$rank\n$suit',
        style: TextStyle(
          color: suitColor,
          fontSize: 19,
          height: 0.95,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    rankPainter.paint(
      canvas,
      const Offset(-cardWidth / 2 + 9, -cardHeight / 2 + 8),
    );

    final suitPainter = TextPainter(
      text: TextSpan(
        text: suit,
        style: TextStyle(color: suitColor, fontSize: 54),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    suitPainter.paint(
      canvas,
      Offset(-suitPainter.width / 2, -suitPainter.height / 2 + 5),
    );

    canvas.restore();
  }
}
