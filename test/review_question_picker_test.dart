import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:question_trainer/utils/review_question_picker.dart';

void main() {
  test('buildReviewQuestionIds includes all wrong and extra correct', () {
    final all = List<String>.generate(20, (i) => 'q_$i');
    final wrong = <String>{'q_2', 'q_4', 'q_6', 'q_8'};

    final result = buildReviewQuestionIds(
      allQuestionIds: all,
      wrongQuestionIds: wrong,
      random: Random(42),
    );

    expect(result.toSet().containsAll(wrong), isTrue);
    expect(result.length, 6);
  });

  test('buildReviewQuestionIds returns empty when no mistakes', () {
    final result = buildReviewQuestionIds(
      allQuestionIds: const ['q_1', 'q_2'],
      wrongQuestionIds: const <String>{},
      random: Random(1),
    );

    expect(result, isEmpty);
  });
}
