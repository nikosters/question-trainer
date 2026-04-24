import 'package:flutter_test/flutter_test.dart';

import 'package:question_trainer/models/question_item.dart';

void main() {
  Map<String, dynamic> multipleChoiceJson({String? type}) => {
    if (type != null) 'type': type,
    'id': 'q1',
    'question': 'Вопрос',
    'option_a': 'A',
    'option_b': 'B',
    'option_c': 'C',
    'option_d': 'D',
    'correct_option': 'B',
    'explanation': 'Объяснение',
  };

  Map<String, dynamic> formulaJson({
    List<dynamic>? parts,
    List<dynamic>? blanks,
    Object? distractors = const ['2'],
    String type = 'formula_assembly',
  }) => {
    'id': 'formula_1',
    'type': type,
    'question': 'Восстановите формулу',
    'formula_parts':
        parts ??
        const [
          {'latex': 'S'},
          {'latex': '='},
          {'blank': 'coef'},
          {'latex': 'a'},
          {'latex': 'h'},
        ],
    'blanks':
        blanks ??
        const [
          {'id': 'coef', 'answer': r'\frac{1}{2}'},
        ],
    if (distractors != null) 'distractors': distractors,
    'explanation': r'$S = \frac{1}{2}ah$',
  };

  test('old JSON without type parses as multiple choice', () {
    final question = QuestionItem.fromJson(multipleChoiceJson());

    expect(question.type, QuestionType.multipleChoice);
    expect(question.correctOption, 'B');
  });

  test('explicit multiple_choice parses as multiple choice', () {
    final question = QuestionItem.fromJson(
      multipleChoiceJson(type: 'multiple_choice'),
    );

    expect(question.type, QuestionType.multipleChoice);
    expect(question.optionFor('B'), 'B');
  });

  test('valid formula_assembly parses', () {
    final question = QuestionItem.fromJson(formulaJson());

    expect(question.type, QuestionType.formulaAssembly);
    expect(question.choiceIdsForQuestion(), ['answer:coef', 'distractor:0']);
    expect(question.isCorrectAnswer(r'{"coef":"\\frac{1}{2}"}'), isTrue);
  });

  test('duplicate blank ids are rejected', () {
    expect(
      () => QuestionItem.fromJson(
        formulaJson(
          blanks: const [
            {'id': 'coef', 'answer': r'\frac{1}{2}'},
            {'id': 'coef', 'answer': r'\frac{1}{3}'},
          ],
        ),
      ),
      throwsFormatException,
    );
  });

  test('blank reference missing from blanks is rejected', () {
    expect(
      () => QuestionItem.fromJson(
        formulaJson(
          parts: const [
            {'latex': 'S'},
            {'blank': 'missing'},
          ],
        ),
      ),
      throwsFormatException,
    );
  });

  test('empty formula_parts is rejected', () {
    expect(
      () => QuestionItem.fromJson(formulaJson(parts: const [])),
      throwsFormatException,
    );
  });

  test('empty blanks is rejected', () {
    expect(
      () => QuestionItem.fromJson(formulaJson(blanks: const [])),
      throwsFormatException,
    );
  });

  test('empty blank answer is rejected', () {
    expect(
      () => QuestionItem.fromJson(
        formulaJson(
          blanks: const [
            {'id': 'coef', 'answer': ''},
          ],
        ),
      ),
      throwsFormatException,
    );
  });

  test('unknown type is rejected', () {
    expect(
      () => QuestionItem.fromJson(formulaJson(type: 'unknown')),
      throwsFormatException,
    );
  });
}
