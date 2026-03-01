import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/consent_cubit.dart';
import '../bloc/consent_state.dart';

class ConsentSection extends StatelessWidget {
  const ConsentSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConsentCubit, ConsentState>(
      builder: (_, state) => Column(
        children: [
          CheckboxListTile(
            title: const Text('I consent to camera recording for exam proctoring'),
            value: state.cameraConsent,
            onChanged: (v) => context.read<ConsentCubit>().toggleCamera(v ?? false),
          ),
          CheckboxListTile(
            title: const Text('I agree to privacy policy'),
            value: state.policyAccepted,
            onChanged: (v) => context.read<ConsentCubit>().togglePolicy(v ?? false),
          ),
          TextButton(
            onPressed: () {
              // open policy URL
            },
            child: const Text('View policy'),
          ),
        ],
      ),
    );
  }
}