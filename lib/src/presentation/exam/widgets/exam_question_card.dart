import 'package:flutter/material.dart';

class ExamQuestionCard extends StatelessWidget {
  const ExamQuestionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Question 1', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text(
              'Explain the difference between an abstract class and an interface in Dart and when to use each.',
            ),
          ],
        ),
      ),
    );
  }
}
