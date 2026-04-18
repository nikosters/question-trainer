import 'dart:math';

import 'package:flutter/material.dart';

import 'package:question_trainer/models/question_item.dart';
import 'package:question_trainer/models/question_package_meta.dart';
import 'package:question_trainer/models/quiz_progress.dart';
import 'package:question_trainer/models/quiz_review_data.dart';
import 'package:question_trainer/services/package_storage.dart';
import 'package:question_trainer/utils/review_question_picker.dart';
import 'package:question_trainer/widgets/formula_text.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({
    required this.packageMeta,
    required this.storage,
    this.resumeProgress = true,
    this.startReviewData,
    super.key,
  });

  final QuestionPackageMeta packageMeta;
  final PackageStorage storage;
  final bool resumeProgress;
  final QuizReviewData? startReviewData;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final Random _random = Random();

  bool _isLoading = true;
  bool _isReviewMode = false;
  String? _error;
  List<QuestionItem> _questions = const [];
  List<List<String>> _optionOrder = const [];
  List<String> _activeReviewQuestionIds = const [];
  Set<String> _wrongQuestionIds = <String>{};
  Map<String, String> _answersByQuestionId = <String, String>{};

  int _currentIndex = 0;
  int _correctAnswers = 0;
  String? _selectedOption;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isReviewMode = false;
    });

    try {
      final loadedQuestions = await widget.storage.loadQuestions(
        widget.packageMeta.id,
      );

      final startReviewData = widget.startReviewData;
      if (startReviewData != null) {
        final reviewQuestions = _buildReviewQuestionsFromHistory(
          loadedQuestions,
          startReviewData,
        );
        if (reviewQuestions.isEmpty) {
          throw const FormatException(
            'Нет доступных вопросов для работы над ошибками.',
          );
        }

        if (mounted) {
          setState(() {
            _questions = reviewQuestions;
            _optionOrder = _buildShuffledOptionOrder(reviewQuestions.length);
            _activeReviewQuestionIds = reviewQuestions
                .map((question) => question.id)
                .toList(growable: false);
            _answersByQuestionId = <String, String>{};
            _wrongQuestionIds = <String>{};
            _currentIndex = 0;
            _correctAnswers = 0;
            _selectedOption = null;
            _isReviewMode = true;
          });
        }
        return;
      }

      final progress = widget.resumeProgress
          ? await widget.storage.loadProgress(widget.packageMeta.id)
          : null;
      final restoredProgress =
          progress != null && _isProgressValid(progress, loadedQuestions)
          ? progress
          : null;

      final questions = restoredProgress != null
          ? _questionsFromProgress(restoredProgress, loadedQuestions)
          : _buildShuffledQuestions(loadedQuestions);
      final optionOrder = restoredProgress != null
          ? _optionOrderFromProgress(restoredProgress, questions)
          : _buildShuffledOptionOrder(questions.length);

      final answersByQuestionId = restoredProgress != null
          ? _normalizedAnswers(restoredProgress, questions)
          : <String, String>{};
      final currentIndex = restoredProgress != null
          ? restoredProgress.currentIndex.clamp(0, questions.length)
          : 0;
      final selectedOption = currentIndex < questions.length
          ? answersByQuestionId[questions[currentIndex].id]
          : null;
      final correctAnswers = restoredProgress != null
          ? restoredProgress.correctAnswers.clamp(0, questions.length)
          : 0;
      final wrongQuestionIds = restoredProgress != null
          ? _detectWrongQuestionIds(questions, answersByQuestionId)
          : <String>{};

      if (mounted) {
        setState(() {
          _questions = questions;
          _optionOrder = optionOrder;
          _answersByQuestionId = answersByQuestionId;
          _activeReviewQuestionIds = const [];
          _wrongQuestionIds = wrongQuestionIds;
          _currentIndex = currentIndex;
          _correctAnswers = correctAnswers;
          _selectedOption = selectedOption;
          _isReviewMode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _selectOption(String option) {
    if (_selectedOption != null) {
      return;
    }

    final current = _questions[_currentIndex];
    final isCorrect = current.correctOption == option;
    final updatedAnswers = Map<String, String>.from(_answersByQuestionId)
      ..[current.id] = option;
    final updatedWrongIds = Set<String>.from(_wrongQuestionIds);
    if (isCorrect) {
      updatedWrongIds.remove(current.id);
    } else {
      updatedWrongIds.add(current.id);
    }

    setState(() {
      _selectedOption = option;
      _answersByQuestionId = updatedAnswers;
      _wrongQuestionIds = updatedWrongIds;
      if (isCorrect) {
        _correctAnswers++;
      }
    });

    _saveProgressIfNeeded();
  }

  Future<void> _nextQuestion() async {
    if (_currentIndex >= _questions.length - 1) {
      if (!_isReviewMode) {
        await widget.storage.saveReviewData(
          QuizReviewData(
            packageId: widget.packageMeta.id,
            allQuestionIds: _questions.map((question) => question.id).toList(),
            wrongQuestionIds: _wrongQuestionIds,
            updatedAt: DateTime.now(),
          ),
        );
        await widget.storage.clearProgress(widget.packageMeta.id);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _currentIndex = _questions.length;
        _selectedOption = null;
      });
      return;
    }

    final nextIndex = _currentIndex + 1;
    final nextSelected = _answersByQuestionId[_questions[nextIndex].id];

    setState(() {
      _currentIndex = nextIndex;
      _selectedOption = nextSelected;
    });

    await _saveProgressIfNeeded();
  }

  Future<void> _saveProgressIfNeeded() async {
    if (_isReviewMode ||
        _questions.isEmpty ||
        _currentIndex >= _questions.length) {
      return;
    }

    final optionOrderByQuestionId = <String, List<String>>{};
    for (var i = 0; i < _questions.length; i++) {
      optionOrderByQuestionId[_questions[i].id] = _optionOrder[i];
    }

    final progress = QuizProgress(
      packageId: widget.packageMeta.id,
      orderedQuestionIds: _questions.map((q) => q.id).toList(growable: false),
      optionOrderByQuestionId: optionOrderByQuestionId,
      answersByQuestionId: _answersByQuestionId,
      currentIndex: _currentIndex,
      correctAnswers: _correctAnswers,
      updatedAt: DateTime.now(),
    );
    await widget.storage.saveProgress(progress);
  }

  List<QuestionItem> _buildShuffledQuestions(
    List<QuestionItem> loadedQuestions,
  ) {
    final questions = List<QuestionItem>.from(loadedQuestions);
    questions.shuffle(_random);
    return List<QuestionItem>.unmodifiable(questions);
  }

  List<List<String>> _buildShuffledOptionOrder(int questionCount) {
    return List<List<String>>.generate(questionCount, (_) {
      final options = ['A', 'B', 'C', 'D'];
      options.shuffle(_random);
      return List<String>.unmodifiable(options);
    }, growable: false);
  }

  bool _isProgressValid(
    QuizProgress progress,
    List<QuestionItem> loadedQuestions,
  ) {
    if (progress.packageId != widget.packageMeta.id) {
      return false;
    }

    final loadedIds = loadedQuestions.map((q) => q.id).toSet();
    final progressIds = progress.orderedQuestionIds.toSet();
    if (loadedIds.length != progressIds.length ||
        !loadedIds.containsAll(progressIds)) {
      return false;
    }

    if (progress.currentIndex < 0 ||
        progress.currentIndex > progress.orderedQuestionIds.length) {
      return false;
    }

    return true;
  }

  List<QuestionItem> _questionsFromProgress(
    QuizProgress progress,
    List<QuestionItem> loadedQuestions,
  ) {
    final byId = {
      for (final question in loadedQuestions) question.id: question,
    };
    return progress.orderedQuestionIds
        .map((id) => byId[id])
        .whereType<QuestionItem>()
        .toList(growable: false);
  }

  List<List<String>> _optionOrderFromProgress(
    QuizProgress progress,
    List<QuestionItem> questions,
  ) {
    return questions
        .map((question) {
          final saved = progress.optionOrderByQuestionId[question.id];
          if (saved != null && saved.length == 4 && saved.toSet().length == 4) {
            return saved;
          }

          final fallback = ['A', 'B', 'C', 'D'];
          fallback.shuffle(_random);
          return List<String>.unmodifiable(fallback);
        })
        .toList(growable: false);
  }

  Map<String, String> _normalizedAnswers(
    QuizProgress progress,
    List<QuestionItem> questions,
  ) {
    final availableIds = questions.map((q) => q.id).toSet();
    final filtered = <String, String>{};
    for (final entry in progress.answersByQuestionId.entries) {
      if (availableIds.contains(entry.key) &&
          ['A', 'B', 'C', 'D'].contains(entry.value)) {
        filtered[entry.key] = entry.value;
      }
    }
    return filtered;
  }

  Set<String> _detectWrongQuestionIds(
    List<QuestionItem> questions,
    Map<String, String> answersByQuestionId,
  ) {
    final byId = {for (final question in questions) question.id: question};
    final wrongIds = <String>{};
    for (final entry in answersByQuestionId.entries) {
      final question = byId[entry.key];
      if (question != null && question.correctOption != entry.value) {
        wrongIds.add(entry.key);
      }
    }
    return wrongIds;
  }

  List<QuestionItem> _buildReviewQuestionsFromHistory(
    List<QuestionItem> allQuestions,
    QuizReviewData reviewData,
  ) {
    final availableIds = allQuestions.map((question) => question.id).toSet();
    final normalizedAllIds = reviewData.allQuestionIds
        .where(availableIds.contains)
        .toList(growable: false);
    final normalizedWrongIds = Set<String>.from(reviewData.wrongQuestionIds)
      ..removeWhere((id) => !availableIds.contains(id));

    final reviewIds = buildReviewQuestionIds(
      allQuestionIds: normalizedAllIds,
      wrongQuestionIds: normalizedWrongIds,
      random: _random,
    );
    if (reviewIds.isEmpty) {
      return const [];
    }

    final byId = {for (final question in allQuestions) question.id: question};
    return reviewIds
        .map((id) => byId[id])
        .whereType<QuestionItem>()
        .toList(growable: false);
  }

  void _startReviewMode() {
    final questionIds = _questions.map((q) => q.id).toList(growable: false);
    final reviewIds = buildReviewQuestionIds(
      allQuestionIds: questionIds,
      wrongQuestionIds: _wrongQuestionIds,
      random: _random,
    );
    if (reviewIds.isEmpty) {
      _showMessage('Нет вопросов для работы над ошибками.');
      return;
    }

    _startReviewSession(reviewIds);
  }

  void _restartReviewMode() {
    if (_activeReviewQuestionIds.isEmpty) {
      _showMessage('Нет сохраненного набора для повторного разбора.');
      return;
    }

    _startReviewSession(_activeReviewQuestionIds);
  }

  void _startReviewSession(List<String> reviewIds) {
    final normalizedReviewIds = List<String>.from(reviewIds, growable: false);

    final byId = {for (final question in _questions) question.id: question};
    final reviewQuestions = normalizedReviewIds
        .map((id) => byId[id])
        .whereType<QuestionItem>()
        .toList(growable: false);

    setState(() {
      _isReviewMode = true;
      _questions = reviewQuestions;
      _optionOrder = _buildShuffledOptionOrder(reviewQuestions.length);
      _activeReviewQuestionIds = normalizedReviewIds;
      _currentIndex = 0;
      _correctAnswers = 0;
      _selectedOption = null;
      _answersByQuestionId = <String, String>{};
      _wrongQuestionIds = <String>{};
    });
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.packageMeta.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.packageMeta.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Не удалось загрузить вопросы:\n$_error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loadQuestions,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_currentIndex >= _questions.length) {
      final total = _questions.length;
      final percent = total == 0
          ? 0
          : ((_correctAnswers / total) * 100).round();
      final canReview = !_isReviewMode && _wrongQuestionIds.isNotEmpty;

      return Scaffold(
        appBar: AppBar(title: Text(widget.packageMeta.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events_outlined, size: 56),
                const SizedBox(height: 12),
                Text(
                  _isReviewMode
                      ? 'Работа над ошибками: $_correctAnswers из $total'
                      : 'Результат: $_correctAnswers из $total',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '$percent%',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isReviewMode
                      ? _restartReviewMode
                      : _loadQuestions,
                  icon: const Icon(Icons.replay_rounded),
                  label: Text(
                    _isReviewMode ? 'Пройти разбор еще раз' : 'Пройти еще раз',
                  ),
                ),
                if (canReview) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _startReviewMode,
                    icon: const Icon(Icons.rule_folder_outlined),
                    label: Text(
                      'Работа над ошибками (${_wrongQuestionIds.length})',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final current = _questions[_currentIndex];
    final optionKeys = _currentIndex < _optionOrder.length
        ? _optionOrder[_currentIndex]
        : const ['A', 'B', 'C', 'D'];

    return Scaffold(
      appBar: AppBar(title: Text(widget.packageMeta.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isReviewMode
                  ? 'Разбор: вопрос ${_currentIndex + 1} из ${_questions.length}'
                  : 'Вопрос ${_currentIndex + 1} из ${_questions.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (current.topic.isNotEmpty || current.difficulty.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (current.topic.isNotEmpty)
                    Chip(label: Text(current.topic)),
                  if (current.difficulty.isNotEmpty)
                    Chip(label: Text(current.difficulty)),
                ],
              ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FormulaText(
                  current.question,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...optionKeys.asMap().entries.map((entry) {
              final index = entry.key;
              final optionKey = entry.value;
              final optionLabel = String.fromCharCode(
                'A'.codeUnitAt(0) + index,
              );
              final optionText = current.optionFor(optionKey);
              final selected = _selectedOption;
              final answered = selected != null;
              final isCorrect = current.correctOption == optionKey;
              final isSelected = selected == optionKey;

              Color? backgroundColor;
              if (answered && isCorrect) {
                backgroundColor = Colors.green.withValues(alpha: 0.15);
              } else if (answered && isSelected && !isCorrect) {
                backgroundColor = Colors.red.withValues(alpha: 0.15);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: answered ? null : () => _selectOption(optionKey),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(radius: 14, child: Text(optionLabel)),
                          const SizedBox(width: 12),
                          Expanded(child: FormulaText(optionText)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (_selectedOption != null) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FormulaText(current.explanation),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _nextQuestion,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  _currentIndex == _questions.length - 1
                      ? 'Завершить'
                      : 'Следующий вопрос',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
