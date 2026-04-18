class QuestionItem {
  const QuestionItem({
    required this.id,
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    required this.explanation,
    required this.topic,
    required this.difficulty,
  });

  final String id;
  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctOption;
  final String explanation;
  final String topic;
  final String difficulty;

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

  factory QuestionItem.fromJson(Map<String, dynamic> json) {
    final correct = (json['correct_option'] as String).trim().toUpperCase();
    if (!['A', 'B', 'C', 'D'].contains(correct)) {
      throw const FormatException(
        'correct_option должен быть одним из: A, B, C, D.',
      );
    }

    return QuestionItem(
      id: _requiredString(json, 'id'),
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
  }
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
