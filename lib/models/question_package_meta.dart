class QuestionPackageMeta {
  const QuestionPackageMeta({
    required this.id,
    required this.title,
    required this.fileName,
    required this.questionCount,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String fileName;
  final int questionCount;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'fileName': fileName,
    'questionCount': questionCount,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory QuestionPackageMeta.fromJson(Map<String, dynamic> json) {
    return QuestionPackageMeta(
      id: json['id'] as String,
      title: json['title'] as String,
      fileName: json['fileName'] as String,
      questionCount: json['questionCount'] as int,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
