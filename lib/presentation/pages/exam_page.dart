import 'package:flutter/material.dart';

import '../controllers/exam_controller.dart';

class ExamPage extends StatefulWidget {
  const ExamPage({super.key});

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  late final ExamController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ExamController()..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Online Exam')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_controller.consentAccepted) ...[
              _ConsentGate(controller: _controller),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: _ExamQuestionPanel(enabled: _controller.consentAccepted),
            ),
            const SizedBox(height: 16),
            Text(
              _controller.status,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_controller.showPermissionSettingsAction) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _controller.openAppSettingsForPermissions,
                  icon: const Icon(Icons.settings),
                  label: const Text('Open App Settings'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_controller.isBusy ||
                            _controller.isRecording ||
                            _controller.examSubmitted)
                        ? null
                        : _controller.startExamAndRecording,
                    icon: const Icon(Icons.play_circle_fill),
                    label: const Text('Start Exam'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_controller.isBusy || _controller.examSubmitted)
                        ? null
                        : _controller.submitExam,
                    icon: const Icon(Icons.assignment_turned_in),
                    label: const Text('Submit Exam'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentGate extends StatelessWidget {
  const _ConsentGate({required this.controller});

  final ExamController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Consent & Privacy',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'By starting the exam, you confirm informed consent for camera-based '
              'proctoring. Data is processed only for exam integrity, uploaded over '
              'encrypted transport, and retained per institutional legal policy.',
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: controller.consentAccepted,
              onChanged: (checked) {
                if (checked == true) {
                  controller.acceptConsent();
                }
              },
              title: const Text('I consent to proctoring and data processing.'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamQuestionPanel extends StatelessWidget {
  const _ExamQuestionPanel({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Question 1', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'Explain the difference between horizontal and vertical scaling in '
                  'distributed systems.',
                ),
                const SizedBox(height: 12),
                const Expanded(
                  child: TextField(
                    maxLines: null,
                    expands: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Write your answer here...',
                    ),
                  ),
                ),
                if (!enabled)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Accept consent to unlock the exam.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
