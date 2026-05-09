import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:question_trainer/models/quiz_progress.dart';
import 'package:question_trainer/models/quiz_review_data.dart';
import 'package:question_trainer/services/package_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('renamePackage updates title and migrates legacy package key', () async {
    SharedPreferences.setMockInitialValues({
      'ege_packages_v1': jsonEncode([
        {
          'id': 'pkg_1',
          'title': 'Старое название',
          'fileName': 'pkg_1.json',
          'questionCount': 10,
          'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
        },
      ]),
    });
    final storage = PackageStorage();

    await storage.renamePackage('pkg_1', 'Новое название');
    final packages = await storage.loadPackages();

    expect(packages.single.title, 'Новое название');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ege_packages_v1'), isNull);
    expect(prefs.getString('question_packages_v1'), isNotNull);
  });

  test('save/load/clear progress lifecycle works', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = PackageStorage();
    final progress = QuizProgress(
      packageId: 'pkg_2',
      orderedQuestionIds: const ['q_1', 'q_2'],
      optionOrderByQuestionId: const {
        'q_1': ['A', 'B', 'C', 'D'],
        'q_2': ['D', 'C', 'B', 'A'],
      },
      answersByQuestionId: const {'q_1': 'A'},
      currentIndex: 1,
      correctAnswers: 1,
      updatedAt: DateTime(2026, 1, 1),
    );

    await storage.saveProgress(progress);
    final loaded = await storage.loadProgress('pkg_2');

    expect(loaded, isNotNull);
    expect(loaded!.packageId, 'pkg_2');
    expect(loaded.currentIndex, 1);
    expect(loaded.answersByQuestionId['q_1'], 'A');

    await storage.clearProgress('pkg_2');
    final cleared = await storage.loadProgress('pkg_2');
    expect(cleared, isNull);
  });

  test('loadAllProgress migrates legacy progress key', () async {
    final progress = QuizProgress(
      packageId: 'pkg_legacy_progress',
      orderedQuestionIds: const ['q_1'],
      optionOrderByQuestionId: const {
        'q_1': ['A', 'B', 'C', 'D'],
      },
      answersByQuestionId: const {'q_1': 'B'},
      currentIndex: 0,
      correctAnswers: 0,
      updatedAt: DateTime(2026, 1, 1),
    );
    SharedPreferences.setMockInitialValues({
      'ege_quiz_progress_v1': jsonEncode({
        progress.packageId: progress.toJson(),
      }),
    });
    final storage = PackageStorage();

    final loaded = await storage.loadAllProgress();

    expect(loaded[progress.packageId], isNotNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ege_quiz_progress_v1'), isNull);
    expect(prefs.getString('question_quiz_progress_v1'), isNotNull);
  });

  test('save/load/clear review lifecycle works', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = PackageStorage();
    final reviewData = QuizReviewData(
      packageId: 'pkg_3',
      allQuestionIds: const ['q_1', 'q_2', 'q_3'],
      wrongQuestionIds: const {'q_2'},
      updatedAt: DateTime(2026, 1, 1),
    );

    await storage.saveReviewData(reviewData);
    final loaded = await storage.loadReviewData('pkg_3');

    expect(loaded, isNotNull);
    expect(loaded!.allQuestionIds, ['q_1', 'q_2', 'q_3']);
    expect(loaded.wrongQuestionIds, {'q_2'});

    await storage.clearReviewData('pkg_3');
    final cleared = await storage.loadReviewData('pkg_3');
    expect(cleared, isNull);
  });

  test('loadAllReviewData migrates legacy review key', () async {
    final reviewData = QuizReviewData(
      packageId: 'pkg_legacy_review',
      allQuestionIds: const ['q_1', 'q_2'],
      wrongQuestionIds: const {'q_2'},
      updatedAt: DateTime(2026, 1, 1),
    );
    SharedPreferences.setMockInitialValues({
      'ege_quiz_review_v1': jsonEncode({
        reviewData.packageId: reviewData.toJson(),
      }),
    });
    final storage = PackageStorage();

    final loaded = await storage.loadAllReviewData();

    expect(loaded[reviewData.packageId], isNotNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ege_quiz_review_v1'), isNull);
    expect(prefs.getString('question_quiz_review_v1'), isNotNull);
  });

  test('validatePackageForTesting returns all question errors', () {
    final storage = PackageStorage();
    final package = jsonEncode({
      'questions': [
        {
          'id': 'q_1',
          'question': 'Первый вопрос',
          'option_b': 'B',
          'option_c': 'C',
          'option_d': 'D',
          'correct_option': 'A',
          'explanation': 'Объяснение',
        },
        {
          'id': 'q_2',
          'question': 'Второй вопрос',
          'option_a': 'A',
          'option_b': 'B',
          'option_c': 'C',
          'option_d': 'D',
          'correct_option': 'E',
          'explanation': 'Объяснение',
        },
      ],
    });

    final result = storage.validatePackageForTesting(package);

    expect(result.isValid, isFalse);
    expect(result.errors, hasLength(greaterThan(1)));
    expect(result.message, contains('questions[0]'));
    expect(result.message, contains('questions[1]'));
  });

  test('validatePackageForTesting rejects invalid json syntax', () {
    final storage = PackageStorage();

    final result = storage.validatePackageForTesting('{"questions": [');

    expect(result.isValid, isFalse);
    expect(result.message, startsWith('JSON:'));
  });

  test('validatePackageForTesting reports duplicate ids', () {
    final storage = PackageStorage();
    final package = jsonEncode({
      'questions': [
        _validQuestionJson(id: 'q_1', question: 'Первый вопрос'),
        _validQuestionJson(id: 'q_1', question: 'Второй вопрос'),
      ],
    });

    final result = storage.validatePackageForTesting(package);

    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains('questions[1].id: повторяется значение "q_1".'),
    );
  });

  test('parseQuestionsForTesting rejects duplicate question ids', () {
    final storage = PackageStorage();
    final package = jsonEncode({
      'questions': [
        _validQuestionJson(id: 'q_1', question: 'Первый вопрос'),
        _validQuestionJson(id: 'q_1', question: 'Второй вопрос'),
      ],
    });

    expect(
      () => storage.parseQuestionsForTesting(package),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _validQuestionJson({
  required String id,
  required String question,
}) {
  return {
    'id': id,
    'question': question,
    'option_a': 'A',
    'option_b': 'B',
    'option_c': 'C',
    'option_d': 'D',
    'correct_option': 'A',
    'explanation': 'Объяснение',
  };
}
