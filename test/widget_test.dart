import 'package:flutter_test/flutter_test.dart';

import 'package:snow_bros/main.dart';
import 'package:snow_bros/game/game_screen.dart';

void main() {
  testWidgets('Snow Bros app launches into the game screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SnowBrosApp());
    await tester.pump();

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('Score: 0'), findsOneWidget);
  });
}
