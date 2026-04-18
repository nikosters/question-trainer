import 'package:flutter_test/flutter_test.dart';

import 'package:question_trainer/app.dart';

void main() {
  testWidgets('Main screen is shown', (tester) async {
    await tester.pumpWidget(const QuestionTrainerApp());

    expect(find.text('Пакеты заданий'), findsOneWidget);
  });
}
