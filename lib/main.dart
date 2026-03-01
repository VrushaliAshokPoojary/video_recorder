import 'package:flutter/material.dart';

import 'presentation/pages/exam_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExamRecorderApp());
}

class ExamRecorderApp extends StatelessWidget {
  const ExamRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exam Proctoring Recorder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ExamPage(),
    );
  }
}
