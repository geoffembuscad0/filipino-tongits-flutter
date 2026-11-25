import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tongits_offline/main.dart';

void main() {
  testWidgets('landing screen appears', (tester) async {
    await tester.pumpWidget(const TongitsApp());

    expect(find.text('TONGITS'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
  });
}
