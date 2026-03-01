import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../presentation/consent/bloc/consent_cubit.dart';
import '../presentation/exam/bloc/exam_controller.dart';
import '../presentation/exam/pages/exam_page.dart';
import '../presentation/session/session_controller.dart';
import 'di.dart';

class ExamProctorApp extends StatelessWidget {
  const ExamProctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<SessionController>()..load()),
        BlocProvider(create: (_) => ConsentCubit()),
        BlocProvider(create: (_) => getIt<ExamController>()),
      ],
      child: MaterialApp(
        title: 'Online Exam Proctor',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
        home: const ExamPage(),
      ),
    );
  }
}
