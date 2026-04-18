import 'dart:math';

List<String> buildReviewQuestionIds({
  required List<String> allQuestionIds,
  required Set<String> wrongQuestionIds,
  required Random random,
  double extraCorrectRatio = 0.25,
  int minExtraCorrect = 2,
  int maxExtraCorrect = 10,
}) {
  if (wrongQuestionIds.isEmpty) {
    return const [];
  }

  final wrongInOrder = allQuestionIds
      .where((id) => wrongQuestionIds.contains(id))
      .toList(growable: false);

  final correctPool = allQuestionIds
      .where((id) => !wrongQuestionIds.contains(id))
      .toList(growable: true);
  correctPool.shuffle(random);

  final byRatio = (wrongInOrder.length * extraCorrectRatio).round();
  final extraCount = byRatio.clamp(minExtraCorrect, maxExtraCorrect);
  final limitedExtra = min(extraCount, correctPool.length);

  final mixed = <String>[...wrongInOrder, ...correctPool.take(limitedExtra)];
  mixed.shuffle(random);
  return mixed;
}
