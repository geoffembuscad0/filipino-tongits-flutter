import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tongits_offline/main.dart';
import 'package:flutter_tongits_offline/screens/jack_en_poy_screen.dart';
import 'package:flutter_tongits_offline/widgets/playing_card_view.dart';

void main() {
  testWidgets('landing screen opens Jack-en-Poy', (tester) async {
    await tester.pumpWidget(const TongitsApp());

    expect(find.text('TONGITS'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);

    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();

    expect(find.text('Who goes first?'), findsOneWidget);
    expect(find.text('CPU Player 1'), findsOneWidget);
    expect(find.text('CPU Player 2'), findsOneWidget);
  });

  testWidgets('Jack-en-Poy winner can deal and see portrait hand cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: JackEnPoyScreen(random: Random(1))),
    );

    await tester.tap(find.text('Rock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DEAL CARDS'));
    await tester.pumpAndSettle();

    expect(find.textContaining('First to draw:'), findsOneWidget);
    // The opening player holds 13 cards; the other two hold 12.
    expect(find.textContaining('12 cards'), findsNWidgets(2));
    expect(find.textContaining('13 cards'), findsOneWidget);
    expect(find.text('15 cards remain in the stock.'), findsOneWidget);
    expect(find.text('Your hand'), findsOneWidget);
    // Your hand is 12 cards, or 13 if you won the opening.
    expect(find.byType(PlayingCardView).evaluate().length, anyOf(12, 13));
  });
}