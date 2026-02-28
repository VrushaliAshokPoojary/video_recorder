import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/exam_session.dart';
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
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ExamQuestionCard(),
                const SizedBox(height: 12),
                const TextField(
                  minLines: 8,
                  maxLines: 12,
                  decoration: InputDecoration(border: OutlineInputBorder(), hintText: 'Write your answer here...'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: state.status == ExamStatus.idle || state.status == ExamStatus.error
                      ? () {
                          context.read<ExamController>().startExam(
                                const ExamSession(
                                  examId: 'EX-2026-001',
                                  candidateId: 'CAND-1001',
                                  authToken: 'mock-jwt-token',
                                ),
                              );
                        }
                      : null,
                  child: const Text('Start Exam (Stealth Recording)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: state.status == ExamStatus.running
                      ? () => context.read<ExamController>().endExam()
                      : null,
                  child: const Text('Submit Exam & Upload'),
                ),
                const SizedBox(height: 12),
                Text('Status: ${state.status.name}'),
                if (state.result != null)
                  Text(
                    'Upload Ref: ${state.result!.uploadReference}\nCompression Ratio: '
                    '${(state.result!.compressionRatio * 100).toStringAsFixed(1)}%',
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
