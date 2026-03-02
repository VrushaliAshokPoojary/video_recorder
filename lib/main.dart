import 'package:flutter/material.dart';

import 'core/background/background_initializer.dart';
import 'presentation/pages/exam_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundService();
  runApp(const ProctoringApp());
}

class ProctoringApp extends StatelessWidget {
  const ProctoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Online Exam Proctoring',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ExamPage(),
    );
  }
}
