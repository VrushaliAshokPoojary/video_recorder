import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/exam_controller.dart';

class ExamPage extends StatefulWidget {
  const ExamPage({super.key});

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  final TextEditingController _examIdController =
      TextEditingController(text: 'exam-session-001');
  final TextEditingController _tokenController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ExamController()..initialize(),
      dispose: (_, controller) => controller.disposeController(),
      child: Consumer<ExamController>(
        builder: (context, controller, _) {
          return Scaffold(
            appBar: AppBar(title: const Text('Online Exam')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Exam Interface',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Exam questions would render below. Camera preview intentionally '
                    'is not shown so exam UI remains distraction-free.',
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _examIdController,
                    decoration: const InputDecoration(
                      labelText: 'Exam Session ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tokenController,
                    decoration: const InputDecoration(
                      labelText: 'JWT Token',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: controller.isBusy
                            ? null
                            : () async {
                                await controller.setToken(_tokenController.text);
                                if (!context.mounted) return;
                                await _showConsentDialog(context);
                                if (!context.mounted) return;
                                await controller.startExam(
                                  examId: _examIdController.text,
                                );
                              },
                        child: const Text('Start Recording'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: controller.isBusy
                            ? null
                            : () {
                                controller.stopExam();
                              },
                        child: const Text('Stop Recording'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status: ${controller.statusMessage}'),
                          Text('Exam Running: ${controller.isExamRunning}'),
                          Text('Recording: ${controller.isRecording}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Privacy & Compliance: This feature must only be enabled with '
                    'explicit candidate consent and institution policy alignment. '
                    'Retention period, lawful basis, and user rights should be '
                    'documented before production deployment.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showConsentDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Proctoring Consent'),
        content: const Text(
          'By continuing, you confirm that you obtained explicit consent for '
          'camera-based recording for this exam session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _examIdController.dispose();
    _tokenController.dispose();
    super.dispose();
  }
}
