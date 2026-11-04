import 'package:flutter_test/flutter_test.dart';
import 'package:auto_mail_ai/main.dart';

void main() {
  testWidgets('AutoMailApp smoke and splash test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AutoMailApp());

    // Verify that the title and splash branding render
    expect(find.text('Auto Mail AI'), findsOneWidget);
    expect(find.text('AI Robot Cold Mailer & Resume Tailor'), findsOneWidget);
  });
}
