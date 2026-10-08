import 'package:flutter_test/flutter_test.dart';
import 'package:marketer_system/app/app.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MarketerApp());

    expect(find.text('لوحة التحكم'), findsNWidgets(2));
  });
}
