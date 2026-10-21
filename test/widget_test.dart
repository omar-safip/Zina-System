import 'package:flutter_test/flutter_test.dart';
import 'package:marketer_system/app/app.dart';

void main() {
  testWidgets('App opens the dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const MarketerApp());

    // نتحقق من أن التطبيق فتح صفحة لوحة التحكم.
    expect(find.text('لوحة التحكم'), findsOneWidget);
  });
}
