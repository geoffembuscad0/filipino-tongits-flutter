import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tongits_offline/main.dart';
import 'package:flutter_tongits_offline/screens/dice_roll_screen.dart';
import 'package:flutter_tongits_offline/widgets/playing_card_view.dart';

void main() {
  testWidgets('landing screen opens dice roll screen', (tester) async {
    await tester.pumpWidget(const TongitsApp());

    expect(find.text('TONGITS'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);

    await tester.tap(find.text('PLAY'));

    // Advance through the route transition.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Choose the First Dealer'), findsOneWidget);
    expect(find.text('LOWEST ROLL DEALS'), findsOneWidget);
    expect(find.text('ROLL DICE'), findsOneWidget);

    expect(find.text('CPU Player 1'), findsOneWidget);
    expect(find.text('CPU Player 2'), findsOneWidget);
  });

  testWidgets('dice roll winner can deal and see portrait hand cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: DiceRollScreen(random: Random(1))),
    );

    expect(find.text('ROLL DICE'), findsOneWidget);

    await tester.tap(find.text('ROLL DICE'));
    await tester.pump();

    // The dice animation lasts 2–4 seconds per roll.
    // Pump manually because the Flame game continuously updates.
    for (
      var frame = 0;
      frame < 100 && find.text('DEAL CARDS').evaluate().isEmpty;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(find.text('DEAL CARDS'), findsOneWidget);

    await tester.tap(find.text('DEAL CARDS'));
    await tester.pump();

    expect(find.textContaining('First to play:'), findsOneWidget);
    expect(find.textContaining('12 cards'), findsNWidgets(2));
    expect(find.textContaining('13 cards'), findsOneWidget);
    expect(find.text('15 cards remain in the stock.'), findsOneWidget);

    // Scroll to the hand in case it is below the visible area.
    await tester.ensureVisible(find.text('Your hand'));
    await tester.pump();

    expect(find.text('Your hand'), findsOneWidget);
    expect(
      find.byType(PlayingCardView).evaluate().length,
      anyOf(12, 13),
    );
  });
}