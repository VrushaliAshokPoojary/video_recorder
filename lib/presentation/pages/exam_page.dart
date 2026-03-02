import 'package:flutter/material.dart';

import '../controllers/exam_controller.dart';

class ExamPage extends StatefulWidget {
  const ExamPage({super.key});

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  static const _questions = <String>[
    'Explain the difference between horizontal and vertical scaling in distributed systems.',
    'What is CAP theorem and how does it impact database design decisions?',
    'Describe two strategies to secure REST APIs in mobile-first architectures.',
    'How would you design retry and backoff for unreliable network calls?',
    'Explain how monitoring and observability improve production reliability.',
  ];

  late final ExamController _controller;
  late final List<TextEditingController> _answerControllers;
  int _currentQuestionIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = ExamController()..addListener(_refresh);
    _answerControllers = List<TextEditingController>.generate(
      _questions.length,
      (_) => TextEditingController(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showConsentDialogIfNeeded();
    });
  }

  Future<void> _showConsentDialogIfNeeded() async {
    if (!mounted || _controller.consentAccepted) return;

    var localConsent = _controller.consentAccepted;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Consent & Privacy'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'By starting the exam, you confirm informed consent for '
                    'camera-based proctoring. Data is processed only for exam '
                    'integrity, uploaded over encrypted transport, and retained '
                    'per institutional legal policy.',
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: localConsent,
                    onChanged: (checked) {
                      setState(() {
                        localConsent = checked ?? false;
                      });
                    },
                    title: const Text(
                      'I consent to proctoring and data processing.',
                    ),
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: !localConsent
                      ? null
                      : () async {
                          await _controller.acceptConsent();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                  child: const Text('Continue to Exam'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in _answerControllers) {
      controller.dispose();
    }
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex += 1;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex -= 1;
      });
    }
  }

  bool get _isLastPage => _currentQuestionIndex == _questions.length - 1;
  bool get _isFirstPage => _currentQuestionIndex == 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Exam'),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F8FF), Color(0xFFF0F4FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProgressHeader(
                index: _currentQuestionIndex,
                total: _questions.length,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: IgnorePointer(
                  ignoring: !_controller.consentAccepted,
                  child: Opacity(
                    opacity: _controller.consentAccepted ? 1 : 0.65,
                    child: Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Question ${_currentQuestionIndex + 1}',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _questions[_currentQuestionIndex],
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: TextField(
                                controller:
                                    _answerControllers[_currentQuestionIndex],
                                maxLines: null,
                                expands: true,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Write your answer here...',
                                ),
                              ),
                            ),
                            if (!_controller.consentAccepted)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Accept consent popup to unlock the exam.',
                                  style: TextStyle(color: Colors.orange),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _controller.status,
                style: theme.textTheme.bodyMedium,
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
                  OutlinedButton.icon(
                    onPressed: _isFirstPage ? null : _previousQuestion,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous'),
                  ),
                  const Spacer(),
                  if (_isFirstPage && !_controller.examStarted)
                    FilledButton.icon(
                      onPressed: (_controller.isBusy ||
                              _controller.isRecording ||
                              _controller.examSubmitted ||
                              !_controller.consentAccepted)
                          ? null
                          : _controller.startExamAndRecording,
                      icon: const Icon(Icons.play_circle_fill),
                      label: const Text('Start Exam'),
                    )
                  else if (_isLastPage)
                    FilledButton.icon(
                      onPressed: (_controller.isBusy ||
                              _controller.examSubmitted ||
                              !_controller.examStarted)
                          ? null
                          : _controller.submitExam,
                      icon: const Icon(Icons.assignment_turned_in),
                      label: const Text('End & Submit Exam'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _nextQuestion,
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Next'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = (index + 1) / total;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Question ${index + 1} of $total'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }
}
