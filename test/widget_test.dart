import 'package:flutter_test/flutter_test.dart';
import 'package:exam_prep_app/app.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ExamPrepApp());
    expect(find.text('刷题'), findsOneWidget);
    expect(find.text('模考'), findsOneWidget);
    expect(find.text('岗位'), findsOneWidget);
  });
}
