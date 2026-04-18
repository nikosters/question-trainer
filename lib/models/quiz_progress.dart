class QuizProgress {
  const QuizProgress({
    required this.packageId,
    required this.orderedQuestionIds,
    required this.optionOrderByQuestionId,
    required this.answersByQuestionId,
    required this.currentIndex,
    required this.correctAnswers,
    required this.updatedAt,
  });

  final String packageId;
  final List<String> orderedQuestionIds;
  final Map<String, List<String>> optionOrderByQuestionId;
  final Map<String, String> answersByQuestionId;
  final int currentIndex;
  final int correctAnswers;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'packageId': packageId,
    'orderedQuestionIds': orderedQuestionIds,
    'optionOrderByQuestionId': optionOrderByQuestionId,
    'answersByQuestionId': answersByQuestionId,
    'currentIndex': currentIndex,
    'correctAnswers': correctAnswers,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory QuizProgress.fromJson(Map<String, dynamic> json) {
    final orderedRaw = json['orderedQuestionIds'];
    if (orderedRaw is! List) {
      throw const FormatException('orderedQuestionIds должен быть массивом.');
    }

    final optionOrderRaw = json['optionOrderByQuestionId'];
    if (optionOrderRaw is! Map<String, dynamic>) {
      throw const FormatException(
        'optionOrderByQuestionId должен быть объектом.',
      );
    }

    final answersRaw = json['answersByQuestionId'];
    if (answersRaw is! Map<String, dynamic>) {
      throw const FormatException('answersByQuestionId должен быть объектом.');
    }

    final orderedQuestionIds = orderedRaw
        .map((item) {
          if (item is! String || item.isEmpty) {
            throw const FormatException(
              'orderedQuestionIds должен содержать непустые строки.',
            );
          }
          return item;
        })
        .toList(growable: false);

    final optionOrderByQuestionId = optionOrderRaw.map((key, value) {
      if (value is! List) {
        throw const FormatException(
          'Значения optionOrderByQuestionId должны быть массивами.',
        );
      }

      final items = value
          .map((item) {
            if (item is! String || item.isEmpty) {
              throw const FormatException(
                'Порядок вариантов должен содержать непустые строки.',
              );
            }
            return item;
          })
          .toList(growable: false);
      return MapEntry(key, items);
    });

    final answersByQuestionId = answersRaw.map((key, value) {
      if (value is! String || value.isEmpty) {
        throw const FormatException(
          'answersByQuestionId должен содержать непустые строки.',
        );
      }
      return MapEntry(key, value);
    });

    return QuizProgress(
      packageId: json['packageId'] as String,
      orderedQuestionIds: orderedQuestionIds,
      optionOrderByQuestionId: optionOrderByQuestionId,
      answersByQuestionId: answersByQuestionId,
      currentIndex: json['currentIndex'] as int,
      correctAnswers: json['correctAnswers'] as int,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
