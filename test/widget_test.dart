import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tongits_offline/main.dart';

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

  testWidgets('Jack-en-Poy winner can deal and takes the first turn', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: JackEnPoyScreen(random: Random(1))),
    );

    await tester.tap(find.text('Rock'));
    await tester.pumpAndSettle();

    expect(find.text('wins the opening!'), findsOneWidget);
    expect(find.text('DEAL CARDS'), findsOneWidget);

    await tester.tap(find.text('DEAL CARDS'));
    await tester.pumpAndSettle();

    expect(find.textContaining('First to draw:'), findsOneWidget);
    expect(find.textContaining('12 cards'), findsNWidgets(3));
    expect(find.text('16 cards remain in the stock.'), findsOneWidget);
    expect(find.text('Your hand'), findsOneWidget);
  });
}
