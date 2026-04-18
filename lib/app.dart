import 'package:flutter/material.dart';

import 'package:question_trainer/screens/package_list_page.dart';

class QuestionTrainerApp extends StatelessWidget {
  const QuestionTrainerApp({super.key});

  static const Color _seedColor = Color(0xFF0B6E4F);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Тренажёр заданий',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const PackageListPage(),
    );
  }
}
