import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import 'exam_controller.dart';

class ExamPage extends StatefulWidget {
  const ExamPage({super.key});

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> with WidgetsBindingObserver {
  late final ExamController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ServiceLocator.get<ExamController>()..addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.onAppPaused();
    }
    if (state == AppLifecycleState.resumed) {
      _controller.onAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _controller.status;
    final isRunning = status == ExamStatus.running;

    return Scaffold(
      appBar: AppBar(title: const Text('Online Examination')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Q1. Which architecture best supports testable, scalable Flutter apps?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...const [
              'A. MVC with global mutable state',
              'B. Clean Architecture with dependency inversion',
              'C. Single-widget file for the entire app',
              'D. No architecture needed',
            ].map((option) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(option),
                )),
            const Spacer(),
            if (_controller.error != null)
              Text(
                _controller.error!,
                style: const TextStyle(color: Colors.red),
              ),
            if (_controller.result != null)
              Text(
                'Upload completed (id: ${_controller.result!.uploadId})\n'
                'Compression ratio: '
                '${(_controller.result!.compressionRatio * 100).toStringAsFixed(1)}%',
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: status == ExamStatus.starting || isRunning
                        ? null
                        : _controller.startExam,
                    child: Text(
                      status == ExamStatus.starting
                          ? 'Starting...'
                          : 'Start Exam',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: isRunning ? _controller.endExam : null,
                    child: Text(
                      status == ExamStatus.ending ? 'Submitting...' : 'End Exam',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Compliance: Inform candidates, collect explicit consent, and '
              'retain recordings according to local privacy regulations.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
