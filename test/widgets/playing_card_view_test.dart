import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tongits_offline/game/card.dart';
import 'package:flutter_tongits_offline/widgets/playing_card_view.dart';

void main() {
  testWidgets('renders card rank and suit in portrait orientation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: PlayingCardView(cardId: 26)),
        ),
      ),
    );

    final card = PlayingCard(26);
    expect(card.rankLabel, findsNWidgets(2));
    expect(card.suitSymbol, '♥');
    expect(find.text('A'), findsOneWidget);
    expect(find.text('♥'), findsOneWidget);

    final cardWidget = tester.widget<Container>(
      find.descendant(
        of: find.byType(PlayingCardView),
        matching: find.byType(Container),
      ).first,
    );
    final constraints = tester.getSize(find.byType(PlayingCardView));
    expect(constraints.width, 68);
    expect(constraints.height, 100);
    expect(cardWidget.decoration, isA<BoxDecoration>());
  });

  testWidgets('lays hand cards upright in a horizontal scroll row', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayerHandView(cardIds: [0, 13, 26, 39]),
        ),
      ),
    );

    expect(find.byType(PlayingCardView), findsNWidgets(4));
    expect(find.byType(ListView), findsOneWidget);
    final handList = tester.widget<ListView>(find.byType(ListView));
    expect(handList.scrollDirection, Axis.horizontal);
  });
}
