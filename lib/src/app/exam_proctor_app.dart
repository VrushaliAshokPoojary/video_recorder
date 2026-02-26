import 'package:flutter/material.dart';

import '../presentation/exam/exam_page.dart';

class ExamProctorApp extends StatelessWidget {
  const ExamProctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Exam Proctor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ExamPage(),
    );
  }
}
