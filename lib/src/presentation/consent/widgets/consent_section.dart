import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/consent_cubit.dart';
import '../bloc/consent_state.dart';

class ConsentSection extends StatelessWidget {
  const ConsentSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: BlocBuilder<ConsentCubit, ConsentState>(
          builder: (context, state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Required before exam start',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: state.cameraConsent,
                  onChanged: (value) =>
                      context.read<ConsentCubit>().setCameraConsent(value ?? false),
                  title: const Text('I consent to camera recording for exam proctoring.'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: state.policyAccepted,
                  onChanged: (value) =>
                      context.read<ConsentCubit>().setPolicyAccepted(value ?? false),
                  title: const Text('I agree to the privacy policy and legal terms.'),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Add your hosted privacy policy URL here.',
                          ),
                        ),
                      );
                    },
                    child: const Text('View Privacy Policy'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
