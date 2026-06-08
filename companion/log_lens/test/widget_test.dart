import 'package:flutter_test/flutter_test.dart';

import 'package:log_lens/src/app.dart';
import 'package:log_lens/src/app_picker_screen.dart';

void main() {
  testWidgets('Log Lens launches into the app picker', (WidgetTester tester) async {
    await tester.pumpWidget(const LogLensApp());
    await tester.pump();

    expect(find.byType(AppPickerScreen), findsOneWidget);
    expect(find.text('Log Lens'), findsOneWidget);
  });
}
