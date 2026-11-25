import 'package:flutter/material.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How to Play')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text(
            'Welcome to Tongits',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'A three-player card game: you play against two CPU opponents. '
            'This offline project is still in development, so some rules '
            'and scoring details may change.',
          ),
          SizedBox(height: 24),
          _GuideSection(
            icon: Icons.sports_kabaddi,
            title: 'Choose who starts',
            description:
                'Before the cards are dealt, play Jack-en-Poy '
                '(Rock, Paper, Scissors). The winner gets the first turn.',
          ),
          _GuideSection(
            icon: Icons.style,
            title: 'Make card groups',
            description:
                'Look for melds: sets of cards with the same rank, or runs '
                'of consecutive ranks in the same suit. The exact rules '
                'and scoring will be finalized as the game is built.',
          ),
          _GuideSection(
            icon: Icons.swap_vert,
            title: 'Take your turn',
            description:
                'On your turn, draw a card, improve your hand where possible, '
                'then discard a card. CPU opponents follow the same turn flow.',
          ),
          _GuideSection(
            icon: Icons.emoji_events_outlined,
            title: 'Play offline',
            description:
                'The game is designed for local play against CPU opponents. '
                'No account, server, or internet connection is needed to play.',
          ),
          SizedBox(height: 16),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'This is a personal learning project. Tongits rules can vary, '
                'and the in-game rules will reflect the version chosen for '
                'this game.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
