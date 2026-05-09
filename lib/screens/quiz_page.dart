import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import 'package:question_trainer/models/question_item.dart';
import 'package:question_trainer/models/question_package_meta.dart';
import 'package:question_trainer/models/quiz_progress.dart';
import 'package:question_trainer/models/quiz_review_data.dart';
import 'package:question_trainer/services/package_storage.dart';
import 'package:question_trainer/utils/review_question_picker.dart';
import 'package:question_trainer/widgets/formula_text.dart';

class _FormulaDisplayItem {
  const _FormulaDisplayItem({required this.index, required this.part});

  final int index;
  final FormulaPart part;
}

class _FormulaDisplayGroup {
  const _FormulaDisplayGroup({required this.index, required this.items});

  final int index;
  final List<_FormulaDisplayItem> items;
}

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
  static const double _formulaTokenMinHeight = 56;
  static const double _formulaBlankSize = 56;

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
  Map<String, String> _formulaDraftByBlankId = <String, String>{};
  String? _selectedBlankId;

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
          final firstQuestion = reviewQuestions.first;
          setState(() {
            _questions = reviewQuestions;
            _optionOrder = _buildShuffledOptionOrder(reviewQuestions);
            _activeReviewQuestionIds = reviewQuestions
                .map((question) => question.id)
                .toList(growable: false);
            _answersByQuestionId = <String, String>{};
            _wrongQuestionIds = <String>{};
            _currentIndex = 0;
            _correctAnswers = 0;
            _selectedOption = null;
            _formulaDraftByBlankId = <String, String>{};
            _selectedBlankId = _initialSelectedBlankId(
              firstQuestion,
              const <String, String>{},
              null,
            );
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
          : _buildShuffledOptionOrder(questions);

      final answersByQuestionId = restoredProgress != null
          ? _normalizedAnswers(restoredProgress, questions)
          : <String, String>{};
      final currentIndex = restoredProgress != null
          ? restoredProgress.currentIndex.clamp(0, questions.length)
          : 0;
      final selectedOption = currentIndex < questions.length
          ? answersByQuestionId[questions[currentIndex].id]
          : null;
      final formulaDraftByBlankId =
          selectedOption != null && currentIndex < questions.length
          ? _formulaDraftFromAnswer(questions[currentIndex], selectedOption)
          : <String, String>{};
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
          _formulaDraftByBlankId = formulaDraftByBlankId;
          _selectedBlankId = currentIndex < questions.length
              ? _initialSelectedBlankId(
                  questions[currentIndex],
                  formulaDraftByBlankId,
                  selectedOption,
                )
              : null;
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

  void _selectFormulaBlank(String blankId) {
    if (_selectedOption != null) {
      return;
    }

    final updatedDraft = Map<String, String>.from(_formulaDraftByBlankId);
    if (updatedDraft.remove(blankId) != null) {
      setState(() {
        _formulaDraftByBlankId = updatedDraft;
        _selectedBlankId = blankId;
      });
      return;
    }

    setState(() {
      _selectedBlankId = blankId;
    });
  }

  void _selectFormulaChoice(String choiceId) {
    if (_selectedOption != null || _selectedBlankId == null) {
      return;
    }

    final current = _questions[_currentIndex];
    final updatedDraft = Map<String, String>.from(_formulaDraftByBlankId)
      ..[_selectedBlankId!] = choiceId;

    setState(() {
      _formulaDraftByBlankId = updatedDraft;
      _selectedBlankId = _nextEmptyBlankId(current, updatedDraft);
    });
  }

  void _submitFormulaAssembly() {
    if (_selectedOption != null) {
      return;
    }

    final current = _questions[_currentIndex];
    final encodedAnswer = _encodeFormulaDraft(current, _formulaDraftByBlankId);
    final isCorrect = current.isCorrectAnswer(encodedAnswer);
    final updatedAnswers = Map<String, String>.from(_answersByQuestionId)
      ..[current.id] = encodedAnswer;
    final updatedWrongIds = Set<String>.from(_wrongQuestionIds);
    if (isCorrect) {
      updatedWrongIds.remove(current.id);
    } else {
      updatedWrongIds.add(current.id);
    }

    setState(() {
      _selectedOption = encodedAnswer;
      _answersByQuestionId = updatedAnswers;
      _wrongQuestionIds = updatedWrongIds;
      _selectedBlankId = null;
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
    final nextDraft = nextSelected == null
        ? <String, String>{}
        : _formulaDraftFromAnswer(_questions[nextIndex], nextSelected);

    setState(() {
      _currentIndex = nextIndex;
      _selectedOption = nextSelected;
      _formulaDraftByBlankId = nextDraft;
      _selectedBlankId = _initialSelectedBlankId(
        _questions[nextIndex],
        nextDraft,
        nextSelected,
      );
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

  List<List<String>> _buildShuffledOptionOrder(List<QuestionItem> questions) {
    return List<List<String>>.generate(questions.length, (index) {
      final options = questions[index].choiceIdsForQuestion();
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
          final expected = question.choiceIdsForQuestion();
          if (saved != null &&
              saved.length == expected.length &&
              saved.toSet().length == expected.length &&
              saved.toSet().containsAll(expected)) {
            return saved;
          }

          final fallback = question.choiceIdsForQuestion();
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
    final byId = {for (final question in questions) question.id: question};
    final filtered = <String, String>{};
    for (final entry in progress.answersByQuestionId.entries) {
      final question = byId[entry.key];
      if (!availableIds.contains(entry.key) || question == null) {
        continue;
      }

      if (question.type == QuestionType.multipleChoice &&
          ['A', 'B', 'C', 'D'].contains(entry.value)) {
        filtered[entry.key] = entry.value;
      } else if (question.type == QuestionType.formulaAssembly &&
          _formulaDraftFromAnswer(question, entry.value).isNotEmpty) {
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
      if (question != null && !question.isCorrectAnswer(entry.value)) {
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
      _optionOrder = _buildShuffledOptionOrder(reviewQuestions);
      _activeReviewQuestionIds = normalizedReviewIds;
      _currentIndex = 0;
      _correctAnswers = 0;
      _selectedOption = null;
      _formulaDraftByBlankId = <String, String>{};
      _selectedBlankId = reviewQuestions.isEmpty
          ? null
          : _initialSelectedBlankId(
              reviewQuestions.first,
              const <String, String>{},
              null,
            );
      _answersByQuestionId = <String, String>{};
      _wrongQuestionIds = <String>{};
    });
  }

  String? _firstBlankId(QuestionItem question) {
    if (question.type != QuestionType.formulaAssembly) {
      return null;
    }

    final formula = question.formulaAssembly;
    if (formula == null) {
      return null;
    }

    for (final part in formula.parts) {
      final blankId = part.blankId;
      if (blankId != null) {
        return blankId;
      }
    }
    return null;
  }

  String? _nextEmptyBlankId(
    QuestionItem question,
    Map<String, String> draftByBlankId,
  ) {
    if (question.type != QuestionType.formulaAssembly) {
      return null;
    }

    final formula = question.formulaAssembly;
    if (formula == null) {
      return null;
    }

    for (final part in formula.parts) {
      final blankId = part.blankId;
      if (blankId != null && !draftByBlankId.containsKey(blankId)) {
        return blankId;
      }
    }
    return null;
  }

  String? _initialSelectedBlankId(
    QuestionItem question,
    Map<String, String> draftByBlankId,
    String? selectedAnswer,
  ) {
    if (question.type != QuestionType.formulaAssembly ||
        selectedAnswer != null) {
      return null;
    }
    return _nextEmptyBlankId(question, draftByBlankId) ??
        _firstBlankId(question);
  }

  String _encodeFormulaDraft(
    QuestionItem question,
    Map<String, String> draftByBlankId,
  ) {
    final formula = question.formulaAssembly;
    if (formula == null) {
      return '{}';
    }

    final answerByBlankId = <String, String>{};
    for (final blank in formula.blanks) {
      final choiceId = draftByBlankId[blank.id];
      if (choiceId != null) {
        answerByBlankId[blank.id] = question.displayForChoiceId(choiceId);
      }
    }
    return jsonEncode(answerByBlankId);
  }

  Map<String, String> _formulaDraftFromAnswer(
    QuestionItem question,
    String encodedAnswer,
  ) {
    if (question.type != QuestionType.formulaAssembly) {
      return <String, String>{};
    }

    try {
      final decoded = jsonDecode(encodedAnswer);
      if (decoded is! Map<String, dynamic>) {
        return <String, String>{};
      }

      final availableChoices = question.choiceIdsForQuestion();
      final usedChoiceIds = <String>{};
      final draft = <String, String>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! String) {
          continue;
        }

        for (final choiceId in availableChoices) {
          if (usedChoiceIds.contains(choiceId)) {
            continue;
          }
          if (question.displayForChoiceId(choiceId) == value.trim()) {
            draft[entry.key] = choiceId;
            usedChoiceIds.add(choiceId);
            break;
          }
        }
      }
      return draft;
    } on FormatException {
      return <String, String>{};
    }
  }

  Map<String, String> _formulaAnswerFromEncoded(String encodedAnswer) {
    try {
      final decoded = jsonDecode(encodedAnswer);
      if (decoded is! Map<String, dynamic>) {
        return const <String, String>{};
      }
      return decoded.map((key, value) {
        if (value is String) {
          return MapEntry(key, value.trim());
        }
        return MapEntry(key, '');
      });
    } on FormatException {
      return const <String, String>{};
    }
  }

  bool _isFormulaComplete(QuestionItem question) {
    final formula = question.formulaAssembly;
    if (formula == null) {
      return false;
    }
    return formula.blanks.every(
      (blank) => _formulaDraftByBlankId.containsKey(blank.id),
    );
  }

  List<_FormulaDisplayGroup> _formulaDisplayGroups(List<FormulaPart> parts) {
    final groups = <_FormulaDisplayGroup>[];
    var currentItems = <_FormulaDisplayItem>[];
    var groupIndex = 0;

    for (var index = 0; index < parts.length; index += 1) {
      final part = parts[index];
      final startsFractionTail =
          part.latex == '/' &&
          index + 1 < parts.length &&
          parts[index + 1].blankId != null;

      if (startsFractionTail && currentItems.isNotEmpty) {
        groups.add(
          _FormulaDisplayGroup(index: groupIndex, items: currentItems),
        );
        groupIndex += 1;
        currentItems = <_FormulaDisplayItem>[];
      }

      currentItems.add(_FormulaDisplayItem(index: index, part: part));
    }

    if (currentItems.isNotEmpty) {
      groups.add(_FormulaDisplayGroup(index: groupIndex, items: currentItems));
    }

    return groups;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildMathFragment(String latex, {TextStyle? style}) {
    return Math.tex(
      latex,
      mathStyle: MathStyle.text,
      textStyle: style,
      onErrorFallback: (error) => Text(error.message, style: style),
    );
  }

  Widget _buildFormulaToken({
    required Widget child,
    required double maxWidth,
    required EdgeInsetsGeometry padding,
    double? minWidth,
    Color? backgroundColor,
    BoxBorder? border,
    Key? key,
    VoidCallback? onTap,
  }) {
    final content = IntrinsicWidth(
      child: Container(
        key: key,
        constraints: BoxConstraints(
          minWidth: minWidth ?? 0,
          minHeight: _formulaTokenMinHeight,
          maxWidth: maxWidth,
        ),
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: border,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: content,
    );
  }

  Widget _buildFixedFormulaToken(
    BuildContext context,
    String latex,
    double maxWidth,
    int index,
  ) {
    return Padding(
      key: Key('formula_fixed_$index'),
      padding: EdgeInsets.symmetric(horizontal: _formulaLatexInset(latex)),
      child: IntrinsicWidth(
        child: Container(
          constraints: BoxConstraints(
            minHeight: _formulaTokenMinHeight,
            maxWidth: maxWidth,
          ),
          alignment: Alignment.center,
          child: _buildMathFragment(
            latex,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
    );
  }

  double _formulaLatexInset(String latex) {
    return const {
          '=',
          '+',
          '-',
          '/',
          r'\pm',
          r'\cdot',
          r'\times',
        }.contains(latex.trim())
        ? 4
        : 1;
  }

  double _formulaContentMinWidth(String latex, TextStyle? style) {
    final fontSize = style?.fontSize ?? 20;
    final normalized = latex
        .replaceAll(RegExp(r'\\frac\{([^}]*)\}\{([^}]*)\}'), r'$1 $2')
        .replaceAll(RegExp(r'\\sqrt\{([^}]*)\}'), r'√ $1')
        .replaceAll(RegExp(r'\\[a-zA-Z]+'), '  ')
        .replaceAll(RegExp(r'[{}_^]'), '')
        .trim();
    final units = normalized.isEmpty ? latex.length : normalized.length;
    return (units * fontSize * 0.68).clamp(_formulaBlankSize, 240);
  }

  Widget _buildFormulaBlankToken({
    required BuildContext context,
    required QuestionItem question,
    required FormulaBlank blank,
    required double maxWidth,
    required bool answered,
    required Map<String, String> submittedAnswer,
  }) {
    final blankId = blank.id;
    final selectedChoiceId = _formulaDraftByBlankId[blankId];
    final selectedLatex = selectedChoiceId == null
        ? null
        : question.displayForChoiceId(selectedChoiceId);
    final displayedLatex = answered ? blank.answer : selectedLatex;
    final isSelectedBlank = _selectedBlankId == blankId;
    final isCorrect = answered && submittedAnswer[blankId] == blank.answer;

    Color borderColor = Theme.of(context).colorScheme.outline;
    Color? backgroundColor;
    if (answered && isCorrect) {
      borderColor = Colors.green;
      backgroundColor = Colors.green.withValues(alpha: 0.12);
    } else if (answered) {
      borderColor = Colors.red;
      backgroundColor = Colors.red.withValues(alpha: 0.12);
    } else if (isSelectedBlank) {
      borderColor = Theme.of(context).colorScheme.primary;
      backgroundColor = Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.10);
    }

    return _buildFormulaToken(
      key: Key('formula_blank_$blankId'),
      maxWidth: maxWidth,
      minWidth: displayedLatex == null
          ? _formulaBlankSize
          : min(
              maxWidth,
              _formulaContentMinWidth(
                    displayedLatex,
                    Theme.of(context).textTheme.titleLarge,
                  ) +
                  32,
            ),
      padding: EdgeInsets.symmetric(
        horizontal: displayedLatex == null ? 4 : 16,
        vertical: 4,
      ),
      backgroundColor: backgroundColor,
      border: Border.all(color: borderColor),
      onTap: answered ? null : () => _selectFormulaBlank(blankId),
      child: displayedLatex == null
          ? const SizedBox(width: 28, height: 18)
          : _buildMathFragment(
              displayedLatex,
              style: Theme.of(context).textTheme.titleLarge,
            ),
    );
  }

  Widget _buildFormulaChoice({
    required BuildContext context,
    required String choiceId,
    required String latex,
    required double maxWidth,
  }) {
    final enabled = _selectedBlankId != null;
    final colorScheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodyLarge;

    return ConstrainedBox(
      key: Key('formula_choice_$choiceId'),
      constraints: BoxConstraints(
        minWidth: min(maxWidth, _formulaContentMinWidth(latex, style) + 24),
        minHeight: 40,
        maxWidth: maxWidth,
      ),
      child: IntrinsicWidth(
        child: Material(
          color: enabled
              ? colorScheme.surfaceContainerHighest
              : colorScheme.onSurface.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: enabled ? () => _selectFormulaChoice(choiceId) : null,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _buildMathFragment(latex, style: style),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormulaGroup({
    required BuildContext context,
    required QuestionItem question,
    required FormulaAssemblyData formula,
    required _FormulaDisplayGroup group,
    required double maxTokenWidth,
    required bool answered,
    required Map<String, String> submittedAnswer,
  }) {
    final children = group.items
        .map((item) {
          final latex = item.part.latex;
          if (latex != null) {
            return _buildFixedFormulaToken(
              context,
              latex,
              maxTokenWidth,
              item.index,
            );
          }

          final blank = formula.blankById(item.part.blankId!);
          return _buildFormulaBlankToken(
            context: context,
            question: question,
            blank: blank,
            maxWidth: maxTokenWidth,
            answered: answered,
            submittedAnswer: submittedAnswer,
          );
        })
        .toList(growable: false);

    if (children.length == 1) {
      return children.single;
    }

    return Row(
      key: Key('formula_group_${group.index}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }

  List<Widget> _buildMultipleChoiceOptions(
    BuildContext context,
    QuestionItem current,
    List<String> optionKeys,
  ) {
    return optionKeys
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final optionKey = entry.value;
          final optionLabel = String.fromCharCode('A'.codeUnitAt(0) + index);
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
        })
        .toList(growable: false);
  }

  Widget _buildFormulaAssembly(
    BuildContext context,
    QuestionItem current,
    List<String> choiceIds,
  ) {
    final formula = current.formulaAssembly;
    if (formula == null) {
      return const SizedBox.shrink();
    }

    final answered = _selectedOption != null;
    final submittedAnswer = answered
        ? _formulaAnswerFromEncoded(_selectedOption!)
        : const <String, String>{};
    final usedChoiceIds = _formulaDraftByBlankId.values.toSet();
    final availableChoiceIds = choiceIds
        .where((choiceId) => !usedChoiceIds.contains(choiceId))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxTokenWidth = constraints.maxWidth;
                return Wrap(
                  spacing: 0,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: _formulaDisplayGroups(formula.parts)
                      .map((group) {
                        return _buildFormulaGroup(
                          context: context,
                          question: current,
                          formula: formula,
                          group: group,
                          maxTokenWidth: maxTokenWidth,
                          answered: answered,
                          submittedAnswer: submittedAnswer,
                        );
                      })
                      .toList(growable: false),
                );
              },
            ),
          ),
        ),
        if (!answered) ...[
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableChoiceIds
                    .map((choiceId) {
                      return _buildFormulaChoice(
                        context: context,
                        choiceId: choiceId,
                        latex: current.displayForChoiceId(choiceId),
                        maxWidth: constraints.maxWidth,
                      );
                    })
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('formula_check_button'),
            onPressed: _isFormulaComplete(current)
                ? _submitFormulaAssembly
                : null,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Проверить'),
          ),
        ],
      ],
    );
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
        : current.choiceIdsForQuestion();

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
            if (current.type == QuestionType.multipleChoice)
              ..._buildMultipleChoiceOptions(context, current, optionKeys)
            else
              _buildFormulaAssembly(context, current, optionKeys),
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
                key: const Key('next_question_button'),
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
