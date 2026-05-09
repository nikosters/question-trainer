import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:question_trainer/models/question_item.dart';
import 'package:question_trainer/models/question_package_meta.dart';
import 'package:question_trainer/models/quiz_progress.dart';
import 'package:question_trainer/models/quiz_review_data.dart';
import 'package:question_trainer/screens/quiz_page.dart';
import 'package:question_trainer/services/package_storage.dart';

class _FakePackageStorage extends PackageStorage {
  _FakePackageStorage(this.questions);

  final List<QuestionItem> questions;
  QuizReviewData? savedReviewData;
  QuizProgress? savedProgress;

  @override
  Future<List<QuestionItem>> loadQuestions(String packageId) async => questions;

  @override
  Future<QuizProgress?> loadProgress(String packageId) async => null;

  @override
  Future<void> saveProgress(QuizProgress progress) async {
    savedProgress = progress;
  }

  @override
  Future<void> clearProgress(String packageId) async {
    savedProgress = null;
  }

  @override
  Future<void> saveReviewData(QuizReviewData reviewData) async {
    savedReviewData = reviewData;
  }
}

void main() {
  final packageMeta = QuestionPackageMeta(
    id: 'pkg_formula',
    title: 'Формулы',
    fileName: 'pkg_formula.json',
    questionCount: 1,
    updatedAt: DateTime(2026, 1, 1),
  );

  QuestionItem formulaQuestion() {
    return QuestionItem.fromJson({
      'id': 'formula_triangle_area',
      'type': 'formula_assembly',
      'question': 'Восстановите формулу площади треугольника.',
      'formula_parts': [
        {'latex': 'S'},
        {'latex': '='},
        {'blank': 'coef'},
        {'latex': 'a'},
        {'latex': 'h'},
      ],
      'blanks': [
        {'id': 'coef', 'answer': r'\frac{1}{2}'},
      ],
      'distractors': ['2'],
      'explanation': r'$S = \frac{1}{2}ah$',
    });
  }

  QuestionItem twoBlankFormulaQuestion() {
    return QuestionItem.fromJson({
      'id': 'formula_quadratic_roots',
      'type': 'formula_assembly',
      'question': 'Восстановите формулу корней квадратного уравнения.',
      'formula_parts': [
        {'latex': 'x_{1,2}'},
        {'latex': '='},
        {'blank': 'numerator'},
        {'latex': '/'},
        {'blank': 'denominator'},
      ],
      'blanks': [
        {'id': 'numerator', 'answer': r'-b \pm \sqrt{D}'},
        {'id': 'denominator', 'answer': '2a'},
      ],
      'distractors': ['a'],
      'explanation': r'$x = \frac{-b \pm \sqrt{D}}{2a}$',
    });
  }

  Future<_FakePackageStorage> pumpFormulaQuiz(
    WidgetTester tester, {
    List<QuestionItem>? questions,
    QuizReviewData? reviewData,
  }) async {
    final storage = _FakePackageStorage(questions ?? [formulaQuestion()]);
    await tester.pumpWidget(
      MaterialApp(
        home: QuizPage(
          packageMeta: packageMeta,
          storage: storage,
          resumeProgress: false,
          startReviewData: reviewData,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return storage;
  }

  Color? blankBorderColor(WidgetTester tester, String blankId) {
    final container = tester.widget<Container>(
      find.byKey(Key('formula_blank_$blankId')),
    );
    final decoration = container.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    return border.top.color;
  }

  double tokenHeight(WidgetTester tester, Key key) {
    return tester.getSize(find.byKey(key)).height;
  }

  Offset tokenTopLeft(WidgetTester tester, Key key) {
    return tester.getTopLeft(find.byKey(key));
  }

  Offset tokenCenter(WidgetTester tester, Key key) {
    return tester.getCenter(find.byKey(key));
  }

  Rect tokenRect(WidgetTester tester, Key key) {
    return tester.getRect(find.byKey(key));
  }

  Rect mathRectInside(WidgetTester tester, Key key) {
    return tester.getRect(
      find.descendant(of: find.byKey(key), matching: find.byType(Math)).first,
    );
  }

  bool formulaChoiceEnabled(WidgetTester tester, Key key) {
    final inkWell = tester.widget<InkWell>(
      find.descendant(of: find.byKey(key), matching: find.byType(InkWell)),
    );
    return inkWell.onTap != null;
  }

  testWidgets('formula assembly question renders parts and answer chips', (
    tester,
  ) async {
    await pumpFormulaQuiz(tester);

    expect(find.text('Восстановите формулу площади треугольника.'), findsOne);
    expect(find.byKey(const Key('formula_blank_coef')), findsOne);
    expect(find.byKey(const Key('formula_choice_answer:coef')), findsOne);
    expect(find.byKey(const Key('formula_choice_distractor:0')), findsOne);
  });

  testWidgets('formula assembly selects first blank by default', (
    tester,
  ) async {
    await pumpFormulaQuiz(tester);

    final primary = Theme.of(
      tester.element(find.byType(QuizPage)),
    ).colorScheme.primary;

    expect(blankBorderColor(tester, 'coef'), primary);
    expect(
      formulaChoiceEnabled(tester, const Key('formula_choice_answer:coef')),
      isTrue,
    );
  });

  testWidgets(
    'formula assembly advances selected blank after choosing a fragment',
    (tester) async {
      await pumpFormulaQuiz(tester, questions: [twoBlankFormulaQuestion()]);

      await tester.tap(
        find.byKey(const Key('formula_choice_answer:numerator')),
      );
      await tester.pumpAndSettle();

      final primary = Theme.of(
        tester.element(find.byType(QuizPage)),
      ).colorScheme.primary;
      expect(blankBorderColor(tester, 'denominator'), primary);
    },
  );

  testWidgets('filled blank can be cleared and selected again', (tester) async {
    await pumpFormulaQuiz(tester);

    await tester.tap(find.byKey(const Key('formula_choice_answer:coef')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('formula_blank_coef')));
    await tester.pumpAndSettle();

    final primary = Theme.of(
      tester.element(find.byType(QuizPage)),
    ).colorScheme.primary;

    expect(blankBorderColor(tester, 'coef'), primary);
    expect(
      formulaChoiceEnabled(tester, const Key('formula_choice_answer:coef')),
      isTrue,
    );
  });

  testWidgets('fixed formula tokens render as compact inline fragments', (
    tester,
  ) async {
    await pumpFormulaQuiz(tester);

    expect(find.byKey(const Key('formula_fixed_0')), findsOne);
    expect(find.byKey(const Key('formula_blank_coef')), findsOne);

    final fixedRect = tokenRect(tester, const Key('formula_fixed_0'));
    final blankRect = tokenRect(tester, const Key('formula_blank_coef'));

    expect((fixedRect.height - blankRect.height).abs(), lessThanOrEqualTo(2));
    expect(fixedRect.width, lessThan(blankRect.width));
  });

  testWidgets('formula denominator blank stays attached to slash', (
    tester,
  ) async {
    await pumpFormulaQuiz(tester, questions: [twoBlankFormulaQuestion()]);

    final groupFinder = find.byKey(const Key('formula_group_1'));
    expect(groupFinder, findsOne);
    expect(
      find.descendant(
        of: groupFinder,
        matching: find.byKey(const Key('formula_fixed_3')),
      ),
      findsOne,
    );
    expect(
      find.descendant(
        of: groupFinder,
        matching: find.byKey(const Key('formula_blank_denominator')),
      ),
      findsOne,
    );

    final slashTopLeft = tokenTopLeft(tester, const Key('formula_fixed_3'));
    final denominatorTopLeft = tokenTopLeft(
      tester,
      const Key('formula_blank_denominator'),
    );

    expect((denominatorTopLeft.dy - slashTopLeft.dy).abs(), lessThan(2));
    expect(denominatorTopLeft.dx, greaterThan(slashTopLeft.dx));
  });

  testWidgets('formula wraps fraction tail instead of overflowing right edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpFormulaQuiz(tester, questions: [twoBlankFormulaQuestion()]);

    await tester.tap(find.byKey(const Key('formula_choice_answer:numerator')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('formula_choice_distractor:0')));
    await tester.pumpAndSettle();

    final denominatorRect = tokenRect(
      tester,
      const Key('formula_blank_denominator'),
    );

    expect(denominatorRect.right, lessThanOrEqualTo(360));
  });

  testWidgets('triangle formula keeps adjacent multipliers inline', (
    tester,
  ) async {
    await pumpFormulaQuiz(tester);

    final blankRect = tokenRect(tester, const Key('formula_blank_coef'));
    final aRect = tokenRect(tester, const Key('formula_fixed_3'));
    final hRect = tokenRect(tester, const Key('formula_fixed_4'));
    final ahGap = hRect.left - aRect.right;

    expect((aRect.center.dy - hRect.center.dy).abs(), lessThan(2));
    expect((blankRect.center.dy - aRect.center.dy).abs(), lessThan(2));
    expect(ahGap, lessThan(4));
    expect(aRect.left, greaterThanOrEqualTo(blankRect.right));
    expect(hRect.left, greaterThanOrEqualTo(aRect.right));
  });

  testWidgets('triangle formula preserves inline token order', (tester) async {
    await pumpFormulaQuiz(tester);

    final equalsRect = tokenRect(tester, const Key('formula_fixed_1'));
    final blankRect = tokenRect(tester, const Key('formula_blank_coef'));
    final aRect = tokenRect(tester, const Key('formula_fixed_3'));
    final hRect = tokenRect(tester, const Key('formula_fixed_4'));

    expect(equalsRect.right, lessThanOrEqualTo(blankRect.left));
    expect(blankRect.right, lessThanOrEqualTo(aRect.left));
    expect(aRect.right, lessThanOrEqualTo(hRect.left));
  });

  testWidgets(
    'compact fixed tokens keep quadratic formula on one row at phone width',
    (tester) async {
      tester.view.physicalSize = const Size(480, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpFormulaQuiz(tester, questions: [twoBlankFormulaQuestion()]);

      final centers = [
        tokenCenter(tester, const Key('formula_fixed_0')).dy,
        tokenCenter(tester, const Key('formula_fixed_1')).dy,
        tokenCenter(tester, const Key('formula_blank_numerator')).dy,
        tokenCenter(tester, const Key('formula_fixed_3')).dy,
        tokenCenter(tester, const Key('formula_blank_denominator')).dy,
      ];
      final minCenter = centers.reduce((a, b) => a < b ? a : b);
      final maxCenter = centers.reduce((a, b) => a > b ? a : b);

      expect(maxCenter - minCenter, lessThan(2));
    },
  );

  testWidgets('fraction blank renders more compactly', (tester) async {
    await pumpFormulaQuiz(tester);

    await tester.tap(find.byKey(const Key('formula_choice_answer:coef')));
    await tester.pumpAndSettle();

    final fixedHeight = tokenHeight(tester, const Key('formula_fixed_0'));
    final blankHeight = tokenHeight(tester, const Key('formula_blank_coef'));

    expect(blankHeight, lessThanOrEqualTo(fixedHeight * 1.4));
  });

  testWidgets('filled fraction blank centers math content', (tester) async {
    await pumpFormulaQuiz(tester);

    final emptyBlankRect = tokenRect(tester, const Key('formula_blank_coef'));
    await tester.tap(find.byKey(const Key('formula_choice_answer:coef')));
    await tester.pumpAndSettle();

    final blankRect = tokenRect(tester, const Key('formula_blank_coef'));
    final mathRect = mathRectInside(tester, const Key('formula_blank_coef'));

    expect((mathRect.center.dx - blankRect.center.dx).abs(), lessThan(1.5));
    expect((mathRect.center.dy - blankRect.center.dy).abs(), lessThan(1.5));
    expect(blankRect.width, greaterThan(emptyBlankRect.width));
  });

  testWidgets('filled long blank centers math content vertically', (
    tester,
  ) async {
    await pumpFormulaQuiz(tester, questions: [twoBlankFormulaQuestion()]);

    await tester.tap(find.byKey(const Key('formula_choice_answer:numerator')));
    await tester.pumpAndSettle();

    final blankRect = tokenRect(tester, const Key('formula_blank_numerator'));
    final mathRect = mathRectInside(
      tester,
      const Key('formula_blank_numerator'),
    );

    expect((mathRect.center.dy - blankRect.center.dy).abs(), lessThan(1.5));
  });

  testWidgets('long formula choice fits phone viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpFormulaQuiz(tester, questions: [twoBlankFormulaQuestion()]);

    final choiceRect = tokenRect(
      tester,
      const Key('formula_choice_answer:numerator'),
    );

    expect(choiceRect.left, greaterThanOrEqualTo(0));
    expect(choiceRect.right, lessThanOrEqualTo(360));
  });

  testWidgets('formula choices use content based widths', (tester) async {
    await pumpFormulaQuiz(tester, questions: [twoBlankFormulaQuestion()]);

    final shortRect = tokenRect(
      tester,
      const Key('formula_choice_answer:denominator'),
    );
    final longRect = tokenRect(
      tester,
      const Key('formula_choice_answer:numerator'),
    );

    expect(shortRect.width, lessThan(longRect.width));
  });

  testWidgets('long formula choices keep consistent math height', (
    tester,
  ) async {
    await pumpFormulaQuiz(tester, questions: [twoBlankFormulaQuestion()]);

    final shortMathRect = mathRectInside(
      tester,
      const Key('formula_choice_answer:denominator'),
    );
    final longMathRect = mathRectInside(
      tester,
      const Key('formula_choice_answer:numerator'),
    );

    expect(longMathRect.height, greaterThanOrEqualTo(shortMathRect.height));
  });

  testWidgets('fraction formula choice centers math content', (tester) async {
    await pumpFormulaQuiz(tester);

    final choiceRect = tokenRect(
      tester,
      const Key('formula_choice_answer:coef'),
    );
    final mathRect = mathRectInside(
      tester,
      const Key('formula_choice_answer:coef'),
    );

    expect((mathRect.center.dx - choiceRect.center.dx).abs(), lessThan(1.5));
    expect((mathRect.center.dy - choiceRect.center.dy).abs(), lessThan(1.5));
  });

  testWidgets('correct formula assembly increments score and shows result', (
    tester,
  ) async {
    await pumpFormulaQuiz(tester);

    await tester.tap(find.byKey(const Key('formula_choice_answer:coef')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('formula_check_button')));
    await tester.tap(find.byKey(const Key('formula_check_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('next_question_button')));
    await tester.pumpAndSettle();

    expect(find.text('Результат: 1 из 1'), findsOne);
  });

  testWidgets('wrong formula assembly marks question wrong', (tester) async {
    final storage = await pumpFormulaQuiz(tester);

    await tester.tap(find.byKey(const Key('formula_choice_distractor:0')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('formula_check_button')));
    await tester.tap(find.byKey(const Key('formula_check_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('next_question_button')));
    await tester.pumpAndSettle();

    expect(find.text('Результат: 0 из 1'), findsOne);
    expect(storage.savedReviewData!.wrongQuestionIds, {
      'formula_triangle_area',
    });
  });

  testWidgets('incomplete formula assembly cannot be submitted', (
    tester,
  ) async {
    await pumpFormulaQuiz(tester);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('formula_check_button')),
    );

    expect(button.onPressed, isNull);
  });

  testWidgets('review mode includes formula assembly questions', (
    tester,
  ) async {
    await pumpFormulaQuiz(
      tester,
      reviewData: QuizReviewData(
        packageId: packageMeta.id,
        allQuestionIds: const ['formula_triangle_area'],
        wrongQuestionIds: const {'formula_triangle_area'},
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    expect(find.text('Разбор: вопрос 1 из 1'), findsOne);
    expect(find.byKey(const Key('formula_blank_coef')), findsOne);
  });
}
