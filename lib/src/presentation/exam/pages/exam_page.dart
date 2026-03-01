import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/exam_session.dart';
import '../../consent/bloc/consent_cubit.dart';
import '../../consent/bloc/consent_state.dart';
import '../../consent/widgets/consent_section.dart';
import '../../session/session_controller.dart';
import '../bloc/exam_controller.dart';
import '../bloc/exam_state.dart';
import '../widgets/exam_question_card.dart';

class ExamPage extends StatelessWidget {
  const ExamPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Online Examination')),
      body: BlocConsumer<ExamController, ExamState>(
        listener: (context, state) {
          if (state.status == ExamStatus.error && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
        },
        builder: (context, examState) {
          return BlocBuilder<SessionController, SessionState>(
            builder: (context, sessionState) {
              return BlocBuilder<ConsentCubit, ConsentState>(
                builder: (context, consentState) {
                  final canStart =
                      (examState.status == ExamStatus.idle ||
                          examState.status == ExamStatus.error) &&
                      consentState.canStartExam &&
                      sessionState.hasValidSession;

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView(
                      children: [
                        const ExamQuestionCard(),
                        const SizedBox(height: 12),
                        const TextField(
                          minLines: 8,
                          maxLines: 12,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Write your answer here...',
                          ),
                        ),
                        const SizedBox(height: 16),
                        const ConsentSection(),
                        const SizedBox(height: 8),
                        if (!sessionState.hasValidSession)
                          Card(
                            color: Theme.of(context).colorScheme.errorContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                sessionState.error ??
                                    'Session expired. Please login again.',
                              ),
                            ),
                          ),
                        FilledButton(
                          onPressed: canStart
                              ? () {
                                  final session = sessionState.session!;
                                  context.read<ExamController>().startExam(
                                        session: ExamSession(
                                          examId: session.examId,
                                          candidateId: session.candidateId,
                                          authToken: session.token,
                                          uploadId: session.uploadId,
                                          expiresAtUtc: session.expiresAtUtc,
                                        ),
                                        consentAccepted: consentState.canStartExam,
                                      );
                                }
                              : null,
                          child: const Text('Start Exam (Stealth Recording)'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: examState.status == ExamStatus.running
                              ? () => context.read<ExamController>().endExam()
                              : null,
                          child: const Text('Submit Exam & Upload'),
                        ),
                        const SizedBox(height: 12),
                        Text('Status: ${examState.status.name}'),
                        if (examState.result != null)
                          Text(
                            'Upload Ref: ${examState.result!.uploadReference}\nCompression Ratio: '
                            '${(examState.result!.compressionRatio * 100).toStringAsFixed(1)}%',
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
