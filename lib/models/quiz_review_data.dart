class QuizReviewData {
  const QuizReviewData({
    required this.packageId,
    required this.allQuestionIds,
    required this.wrongQuestionIds,
    required this.updatedAt,
  });

  final String packageId;
  final List<String> allQuestionIds;
  final Set<String> wrongQuestionIds;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'packageId': packageId,
    'allQuestionIds': allQuestionIds,
    'wrongQuestionIds': wrongQuestionIds.toList(growable: false),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory QuizReviewData.fromJson(Map<String, dynamic> json) {
    final allQuestionIdsRaw = json['allQuestionIds'];
    if (allQuestionIdsRaw is! List) {
      throw const FormatException('allQuestionIds должен быть массивом.');
    }

    final wrongQuestionIdsRaw = json['wrongQuestionIds'];
    if (wrongQuestionIdsRaw is! List) {
      throw const FormatException('wrongQuestionIds должен быть массивом.');
    }

    final allQuestionIds = allQuestionIdsRaw
        .map((item) {
          if (item is! String || item.isEmpty) {
            throw const FormatException(
              'allQuestionIds должен содержать непустые строки.',
            );
          }
          return item;
        })
        .toList(growable: false);

    final wrongQuestionIds = wrongQuestionIdsRaw.map((item) {
      if (item is! String || item.isEmpty) {
        throw const FormatException(
          'wrongQuestionIds должен содержать непустые строки.',
        );
      }
      return item;
    }).toSet();

    return QuizReviewData(
      packageId: json['packageId'] as String,
      allQuestionIds: allQuestionIds,
      wrongQuestionIds: wrongQuestionIds,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
