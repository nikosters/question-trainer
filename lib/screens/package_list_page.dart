import 'package:flutter/material.dart';

import 'package:question_trainer/models/question_package_meta.dart';
import 'package:question_trainer/models/quiz_progress.dart';
import 'package:question_trainer/models/quiz_review_data.dart';
import 'package:question_trainer/screens/quiz_page.dart';
import 'package:question_trainer/services/package_storage.dart';
import 'package:question_trainer/utils/date_time_format.dart';

enum _QuizLaunchAction { resume, restart }

class PackageListPage extends StatefulWidget {
  const PackageListPage({super.key});

  @override
  State<PackageListPage> createState() => _PackageListPageState();
}

class _PackageListPageState extends State<PackageListPage> {
  final PackageStorage _storage = PackageStorage();

  bool _isLoading = true;
  List<QuestionPackageMeta> _packages = const [];
  Map<String, QuizProgress> _progressByPackageId = const {};
  Map<String, QuizReviewData> _reviewByPackageId = const {};

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _storage.loadPackages(),
        _storage.loadAllProgress(),
        _storage.loadAllReviewData(),
      ]);
      final packages = results[0] as List<QuestionPackageMeta>;
      final progressByPackageId = results[1] as Map<String, QuizProgress>;
      final reviewByPackageId = results[2] as Map<String, QuizReviewData>;

      packages.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      if (mounted) {
        setState(() {
          _packages = packages;
          _progressByPackageId = progressByPackageId;
          _reviewByPackageId = reviewByPackageId;
        });
      }
    } catch (e) {
      _showMessage('Не удалось загрузить пакеты: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _importPackage({QuestionPackageMeta? existing}) async {
    try {
      final result = await _storage.importPackage(existing: existing);
      if (result == null || !mounted) {
        return;
      }

      final actionText = existing == null ? 'добавлен' : 'обновлен';
      _showMessage('Пакет "$result" $actionText');
      await _loadPackages();
    } catch (e) {
      _showMessage('Ошибка импорта: $e');
    }
  }

  Future<void> _deletePackage(QuestionPackageMeta package) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить пакет?'),
        content: Text(
          'Пакет "${package.title}" будет удален без возможности восстановления.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _storage.deletePackage(package.id);
      _showMessage('Пакет удален');
      await _loadPackages();
    } catch (e) {
      _showMessage('Ошибка удаления: $e');
    }
  }

  Future<void> _renamePackage(QuestionPackageMeta package) async {
    final controller = TextEditingController(text: package.title);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Переименовать пакет'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Название пакета',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result == null || result.isEmpty || result == package.title) {
      return;
    }

    try {
      await _storage.renamePackage(package.id, result);
      _showMessage('Пакет переименован');
      await _loadPackages();
    } catch (e) {
      _showMessage('Ошибка переименования: $e');
    }
  }

  Future<void> _openQuiz(QuestionPackageMeta package) async {
    var resumeProgress = false;
    try {
      final progress = await _storage.loadProgress(package.id);
      if (!mounted) {
        return;
      }

      if (progress != null) {
        final action = await showDialog<_QuizLaunchAction>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Найден незавершенный тест'),
            content: const Text(
              'Вы хотите продолжить с места остановки или начать заново?',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(_QuizLaunchAction.restart),
                child: const Text('Заново'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_QuizLaunchAction.resume),
                child: const Text('Продолжить'),
              ),
            ],
          ),
        );

        if (action == null) {
          return;
        }

        if (action == _QuizLaunchAction.resume) {
          resumeProgress = true;
        } else {
          await _storage.clearProgress(package.id);
        }
      }

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => QuizPage(
            packageMeta: package,
            storage: _storage,
            resumeProgress: resumeProgress,
          ),
        ),
      );
      await _loadPackages();
    } catch (e) {
      _showMessage('Не удалось открыть тест: $e');
    }
  }

  Future<void> _openReviewQuiz(QuestionPackageMeta package) async {
    final reviewData = _reviewByPackageId[package.id];
    if (reviewData == null || reviewData.wrongQuestionIds.isEmpty) {
      _showMessage('Сначала завершите тест с ошибками для этого пакета.');
      return;
    }

    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => QuizPage(
            packageMeta: package,
            storage: _storage,
            resumeProgress: false,
            startReviewData: reviewData,
          ),
        ),
      );
      await _loadPackages();
    } catch (e) {
      _showMessage('Не удалось открыть разбор ошибок: $e');
    }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Пакеты заданий')),
      body: RefreshIndicator(
        onRefresh: _loadPackages,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _packages.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.menu_book_rounded, size: 64),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Пока нет пакетов.\nНажмите кнопку ниже, чтобы добавить JSON.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _packages.length,
                itemBuilder: (context, index) {
                  final item = _packages[index];
                  final progress = _progressByPackageId[item.id];
                  final reviewData = _reviewByPackageId[item.id];
                  final canStartReview =
                      reviewData != null &&
                      reviewData.wrongQuestionIds.isNotEmpty;
                  final answeredCount =
                      progress?.answersByQuestionId.length ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text('Вопросов: ${item.questionCount}'),
                          const SizedBox(height: 2),
                          Text(
                            'Прогресс: $answeredCount/${item.questionCount}',
                          ),
                          const SizedBox(height: 2),
                          Text('Обновлен: ${formatDateTime(item.updatedAt)}'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: () => _openQuiz(item),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Начать'),
                              ),
                              if (canStartReview)
                                OutlinedButton.icon(
                                  onPressed: () => _openReviewQuiz(item),
                                  icon: const Icon(Icons.rule_folder_outlined),
                                  label: const Text('Работа над ошибками'),
                                ),
                              OutlinedButton.icon(
                                onPressed: () => _renamePackage(item),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Переименовать'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _importPackage(existing: item),
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text('Обновить'),
                              ),
                              TextButton.icon(
                                onPressed: () => _deletePackage(item),
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('Удалить'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importPackage,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Загрузить пакет'),
      ),
    );
  }
}
