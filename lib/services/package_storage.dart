import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:question_trainer/models/question_item.dart';
import 'package:question_trainer/models/question_package_meta.dart';
import 'package:question_trainer/models/quiz_progress.dart';
import 'package:question_trainer/models/quiz_review_data.dart';

class PackageStorage {
  static const String _prefsKey = 'question_packages_v1';
  static const String _progressPrefsKey = 'question_quiz_progress_v1';
  static const String _reviewPrefsKey = 'question_quiz_review_v1';
  static const String _legacyPrefsKey = 'ege_packages_v1';
  static const String _legacyProgressPrefsKey = 'ege_quiz_progress_v1';
  static const String _legacyReviewPrefsKey = 'ege_quiz_review_v1';
  static final Uuid _uuid = Uuid();

  Future<List<QuestionPackageMeta>> loadPackages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await _loadStoredString(
      prefs,
      key: _prefsKey,
      legacyKey: _legacyPrefsKey,
    );
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (item) => QuestionPackageMeta.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<String?> importPackage({QuestionPackageMeta? existing}) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );

    if (picked == null || picked.files.isEmpty) {
      return null;
    }

    final file = picked.files.first;
    final bytes = await _extractBytes(file);
    final text = utf8.decode(bytes);
    final parsed = _parseQuestions(text);
    final packageTitle = existing?.title ?? _titleFromFilename(file.name);
    final packageId = existing?.id ?? _uuid.v4();

    final dir = await _packageDirectory();
    final saveFileName = '$packageId.json';
    final localFile = File('${dir.path}/$saveFileName');
    await localFile.writeAsBytes(bytes, flush: true);

    final allPackages = await loadPackages();
    final updatedMeta = QuestionPackageMeta(
      id: packageId,
      title: packageTitle,
      fileName: saveFileName,
      questionCount: parsed.length,
      updatedAt: DateTime.now(),
    );

    final filtered = allPackages.where((p) => p.id != packageId).toList();
    filtered.add(updatedMeta);
    await _savePackages(filtered);

    return packageTitle;
  }

  Future<void> deletePackage(String packageId) async {
    final packages = await loadPackages();
    final match = packages.where((p) => p.id == packageId).firstOrNull;
    if (match != null) {
      final dir = await _packageDirectory();
      final file = File('${dir.path}/${match.fileName}');
      if (await file.exists()) {
        await file.delete();
      }
    }

    final filtered = packages.where((p) => p.id != packageId).toList();
    await _savePackages(filtered);
    await clearProgress(packageId);
    await clearReviewData(packageId);
  }

  Future<void> renamePackage(String packageId, String newTitle) async {
    final normalizedTitle = newTitle.trim();
    if (normalizedTitle.isEmpty) {
      throw const FormatException('Название пакета не может быть пустым.');
    }

    final packages = await loadPackages();
    final index = packages.indexWhere((p) => p.id == packageId);
    if (index < 0) {
      throw const FormatException('Пакет не найден.');
    }

    final current = packages[index];
    packages[index] = QuestionPackageMeta(
      id: current.id,
      title: normalizedTitle,
      fileName: current.fileName,
      questionCount: current.questionCount,
      updatedAt: DateTime.now(),
    );
    await _savePackages(packages);
  }

  Future<List<QuestionItem>> loadQuestions(String packageId) async {
    final packages = await loadPackages();
    final package = packages.where((p) => p.id == packageId).firstOrNull;
    if (package == null) {
      throw const FormatException('Пакет не найден.');
    }

    final dir = await _packageDirectory();
    final file = File('${dir.path}/${package.fileName}');
    if (!await file.exists()) {
      throw const FormatException('Файл пакета не найден.');
    }

    final raw = await file.readAsString();
    return _parseQuestions(raw);
  }

  Future<QuizProgress?> loadProgress(String packageId) async {
    final allProgress = await loadAllProgress();
    return allProgress[packageId];
  }

  Future<Map<String, QuizProgress>> loadAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await _loadStoredString(
      prefs,
      key: _progressPrefsKey,
      legacyKey: _legacyProgressPrefsKey,
    );
    if (raw == null || raw.isEmpty) {
      return const <String, QuizProgress>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return const <String, QuizProgress>{};
    }

    final result = <String, QuizProgress>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) {
        continue;
      }
      try {
        result[entry.key] = QuizProgress.fromJson(value);
      } on FormatException {
        continue;
      }
    }
    return result;
  }

  Future<void> saveProgress(QuizProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await _loadStoredString(
      prefs,
      key: _progressPrefsKey,
      legacyKey: _legacyProgressPrefsKey,
    );

    final allProgress = raw == null || raw.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;

    allProgress[progress.packageId] = progress.toJson();
    await prefs.setString(_progressPrefsKey, jsonEncode(allProgress));
  }

  Future<void> clearProgress(String packageId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await _loadStoredString(
      prefs,
      key: _progressPrefsKey,
      legacyKey: _legacyProgressPrefsKey,
    );
    if (raw == null || raw.isEmpty) {
      return;
    }

    final allProgress = jsonDecode(raw);
    if (allProgress is! Map<String, dynamic>) {
      return;
    }

    allProgress.remove(packageId);
    await prefs.setString(_progressPrefsKey, jsonEncode(allProgress));
  }

  Future<QuizReviewData?> loadReviewData(String packageId) async {
    final allReviewData = await loadAllReviewData();
    return allReviewData[packageId];
  }

  Future<Map<String, QuizReviewData>> loadAllReviewData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await _loadStoredString(
      prefs,
      key: _reviewPrefsKey,
      legacyKey: _legacyReviewPrefsKey,
    );
    if (raw == null || raw.isEmpty) {
      return const <String, QuizReviewData>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return const <String, QuizReviewData>{};
    }

    final result = <String, QuizReviewData>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) {
        continue;
      }

      try {
        result[entry.key] = QuizReviewData.fromJson(value);
      } on FormatException {
        continue;
      }
    }
    return result;
  }

  Future<void> saveReviewData(QuizReviewData reviewData) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await _loadStoredString(
      prefs,
      key: _reviewPrefsKey,
      legacyKey: _legacyReviewPrefsKey,
    );

    final allReviewData = raw == null || raw.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;

    allReviewData[reviewData.packageId] = reviewData.toJson();
    await prefs.setString(_reviewPrefsKey, jsonEncode(allReviewData));
  }

  Future<void> clearReviewData(String packageId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await _loadStoredString(
      prefs,
      key: _reviewPrefsKey,
      legacyKey: _legacyReviewPrefsKey,
    );
    if (raw == null || raw.isEmpty) {
      return;
    }

    final allReviewData = jsonDecode(raw);
    if (allReviewData is! Map<String, dynamic>) {
      return;
    }

    allReviewData.remove(packageId);
    await prefs.setString(_reviewPrefsKey, jsonEncode(allReviewData));
  }

  @visibleForTesting
  List<QuestionItem> parseQuestionsForTesting(String jsonContent) {
    return _parseQuestions(jsonContent);
  }

  Future<void> _savePackages(List<QuestionPackageMeta> packages) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = packages.map((e) => e.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(jsonList));
  }

  Future<String?> _loadStoredString(
    SharedPreferences prefs, {
    required String key,
    required String legacyKey,
  }) async {
    final raw = prefs.getString(key);
    if (raw != null && raw.isNotEmpty) {
      return raw;
    }

    final legacyRaw = prefs.getString(legacyKey);
    if (legacyRaw == null || legacyRaw.isEmpty) {
      return legacyRaw;
    }

    await prefs.setString(key, legacyRaw);
    await prefs.remove(legacyKey);
    return legacyRaw;
  }

  Future<Directory> _packageDirectory() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/question_packages');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<int>> _extractBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes!;
    }

    if (file.path != null) {
      return File(file.path!).readAsBytes();
    }

    throw const FormatException('Не удалось прочитать выбранный файл.');
  }

  List<QuestionItem> _parseQuestions(String jsonContent) {
    final root = jsonDecode(jsonContent);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('Корень JSON должен быть объектом.');
    }

    final rawQuestions = root['questions'];
    if (rawQuestions is! List<dynamic>) {
      throw const FormatException('Поле questions должно быть массивом.');
    }

    final ids = <String>{};
    final result = <QuestionItem>[];

    for (final item in rawQuestions) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Каждый вопрос должен быть JSON-объектом.');
      }

      final question = QuestionItem.fromJson(item);
      if (!ids.add(question.id)) {
        throw FormatException('Повторяющийся id в пакете: ${question.id}');
      }
      result.add(question);
    }

    if (result.isEmpty) {
      throw const FormatException('Пакет не содержит вопросов.');
    }

    return result;
  }

  String _titleFromFilename(String name) {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex > 0) {
      return name.substring(0, dotIndex);
    }
    return name;
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
