import 'dart:convert';

enum QuestionType { multipleChoice, formulaAssembly }

class FormulaPart {
  const FormulaPart({this.latex, this.blankId});

  final String? latex;
  final String? blankId;

  bool get isBlank => blankId != null;

  factory FormulaPart.fromJson(Map<String, dynamic> json) {
    final hasLatex = json.containsKey('latex');
    final hasBlank = json.containsKey('blank');
    if (hasLatex == hasBlank) {
      throw const FormatException(
        'Элемент formula_parts должен содержать ровно одно поле: latex или blank.',
      );
    }

    if (hasLatex) {
      return FormulaPart(latex: _requiredString(json, 'latex'));
    }

    return FormulaPart(blankId: _requiredString(json, 'blank'));
  }
}

class FormulaBlank {
  const FormulaBlank({required this.id, required this.answer});

  final String id;
  final String answer;

  factory FormulaBlank.fromJson(Map<String, dynamic> json) {
    return FormulaBlank(
      id: _requiredString(json, 'id'),
      answer: _requiredString(json, 'answer'),
    );
  }
}

class FormulaAssemblyData {
  const FormulaAssemblyData({
    required this.parts,
    required this.blanks,
    required this.distractors,
  });

  final List<FormulaPart> parts;
  final List<FormulaBlank> blanks;
  final List<String> distractors;

  FormulaBlank blankById(String id) {
    return blanks.firstWhere((blank) => blank.id == id);
  }

  factory FormulaAssemblyData.fromJson(Map<String, dynamic> json) {
    final rawParts = json['formula_parts'];
    if (rawParts is! List || rawParts.isEmpty) {
      throw const FormatException(
        'Поле formula_parts должно быть непустым массивом.',
      );
    }

    final rawBlanks = json['blanks'];
    if (rawBlanks is! List || rawBlanks.isEmpty) {
      throw const FormatException('Поле blanks должно быть непустым массивом.');
    }

    final parts = rawParts
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException(
              'Каждый элемент formula_parts должен быть JSON-объектом.',
            );
          }
          return FormulaPart.fromJson(item);
        })
        .toList(growable: false);

    final blanks = rawBlanks
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException(
              'Каждый элемент blanks должен быть JSON-объектом.',
            );
          }
          return FormulaBlank.fromJson(item);
        })
        .toList(growable: false);

    final blankIds = <String>{};
    for (final blank in blanks) {
      if (!blankIds.add(blank.id)) {
        throw FormatException('Повторяющийся id пропуска: ${blank.id}');
      }
    }

    final referencedBlankIds = <String>{};
    for (final part in parts) {
      final blankId = part.blankId;
      if (blankId == null) {
        continue;
      }
      if (!blankIds.contains(blankId)) {
        throw FormatException('Пропуск $blankId не описан в blanks.');
      }
      referencedBlankIds.add(blankId);
    }

    for (final blank in blanks) {
      if (!referencedBlankIds.contains(blank.id)) {
        throw FormatException(
          'Пропуск ${blank.id} должен использоваться в formula_parts.',
        );
      }
    }

    final rawDistractors = json['distractors'];
    final distractors = rawDistractors == null
        ? const <String>[]
        : _stringList(rawDistractors, 'distractors');

    return FormulaAssemblyData(
      parts: parts,
      blanks: blanks,
      distractors: distractors,
    );
  }
}

class QuestionItem {
  const QuestionItem({
    required this.id,
    required this.type,
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    required this.explanation,
    required this.topic,
    required this.difficulty,
    this.formulaAssembly,
  });

  final String id;
  final QuestionType type;
  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctOption;
  final String explanation;
  final String topic;
  final String difficulty;
  final FormulaAssemblyData? formulaAssembly;

  String optionFor(String option) {
    switch (option) {
      case 'A':
        return optionA;
      case 'B':
        return optionB;
      case 'C':
        return optionC;
      case 'D':
        return optionD;
      default:
        return '';
    }
  }

  bool isCorrectAnswer(String encodedAnswer) {
    switch (type) {
      case QuestionType.multipleChoice:
        return correctOption == encodedAnswer;
      case QuestionType.formulaAssembly:
        final formula = formulaAssembly;
        if (formula == null) {
          return false;
        }

        final Object? decoded;
        try {
          decoded = jsonDecode(encodedAnswer);
        } on FormatException {
          return false;
        }
        if (decoded is! Map<String, dynamic>) {
          return false;
        }

        for (final blank in formula.blanks) {
          final answer = decoded[blank.id];
          if (answer is! String || answer.trim() != blank.answer) {
            return false;
          }
        }
        return decoded.length == formula.blanks.length;
    }
  }

  List<String> choiceIdsForQuestion() {
    switch (type) {
      case QuestionType.multipleChoice:
        return const ['A', 'B', 'C', 'D'];
      case QuestionType.formulaAssembly:
        final formula = formulaAssembly;
        if (formula == null) {
          return const [];
        }
        return [
          for (final blank in formula.blanks) 'answer:${blank.id}',
          for (var i = 0; i < formula.distractors.length; i++) 'distractor:$i',
        ];
    }
  }

  String displayForChoiceId(String choiceId) {
    switch (type) {
      case QuestionType.multipleChoice:
        return optionFor(choiceId);
      case QuestionType.formulaAssembly:
        final formula = formulaAssembly;
        if (formula == null) {
          return '';
        }

        if (choiceId.startsWith('answer:')) {
          final blankId = choiceId.substring('answer:'.length);
          return formula.blankById(blankId).answer;
        }
        if (choiceId.startsWith('distractor:')) {
          final index = int.tryParse(choiceId.substring('distractor:'.length));
          if (index != null &&
              index >= 0 &&
              index < formula.distractors.length) {
            return formula.distractors[index];
          }
        }
        return '';
    }
  }

  factory QuestionItem.fromJson(Map<String, dynamic> json) {
    final type = _questionTypeFromJson(json);
    switch (type) {
      case QuestionType.multipleChoice:
        final correct = _requiredString(
          json,
          'correct_option',
        ).trim().toUpperCase();
        if (!['A', 'B', 'C', 'D'].contains(correct)) {
          throw const FormatException(
            'correct_option должен быть одним из: A, B, C, D.',
          );
        }

        return QuestionItem(
          id: _requiredString(json, 'id'),
          type: type,
          question: _requiredString(json, 'question'),
          optionA: _requiredString(json, 'option_a'),
          optionB: _requiredString(json, 'option_b'),
          optionC: _requiredString(json, 'option_c'),
          optionD: _requiredString(json, 'option_d'),
          correctOption: correct,
          explanation: _requiredString(json, 'explanation'),
          topic: (json['topic'] as String?)?.trim() ?? '',
          difficulty: (json['difficulty'] as String?)?.trim() ?? '',
        );
      case QuestionType.formulaAssembly:
        return QuestionItem(
          id: _requiredString(json, 'id'),
          type: type,
          question: _requiredString(json, 'question'),
          optionA: '',
          optionB: '',
          optionC: '',
          optionD: '',
          correctOption: '',
          explanation: _requiredString(json, 'explanation'),
          topic: (json['topic'] as String?)?.trim() ?? '',
          difficulty: (json['difficulty'] as String?)?.trim() ?? '',
          formulaAssembly: FormulaAssemblyData.fromJson(json),
        );
    }
  }
}

QuestionType _questionTypeFromJson(Map<String, dynamic> json) {
  final rawType = json['type'];
  if (rawType == null) {
    return QuestionType.multipleChoice;
  }
  if (rawType is! String || rawType.trim().isEmpty) {
    throw const FormatException('Поле type должно быть непустой строкой.');
  }

  switch (rawType.trim()) {
    case 'multiple_choice':
      return QuestionType.multipleChoice;
    case 'formula_assembly':
      return QuestionType.formulaAssembly;
    default:
      throw FormatException('Неизвестный тип вопроса: $rawType');
  }
}

List<String> _stringList(Object value, String key) {
  if (value is! List) {
    throw FormatException('Поле $key должно быть массивом.');
  }

  return value
      .map((item) {
        if (item is! String || item.trim().isEmpty) {
          throw FormatException('Поле $key должно содержать непустые строки.');
        }
        return item.trim();
      })
      .toList(growable: false);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException(
      'Поле $key обязательно и должно быть непустой строкой.',
    );
  }
  return value.trim();
}
