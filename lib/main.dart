import 'package:flutter/material.dart';

import 'src/app/exam_proctor_app.dart';
import 'src/core/di/service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServiceLocator.setup();
  runApp(const ExamProctorApp());
}
