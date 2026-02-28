import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../presentation/exam/bloc/exam_controller.dart';
import '../presentation/exam/pages/exam_page.dart';
import 'di.dart';

class ExamProctorApp extends StatelessWidget {
  const ExamProctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Online Exam Proctor',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: BlocProvider(
        create: (_) => getIt<ExamController>(),
        child: const ExamPage(),
      ),
    );
  }
}
