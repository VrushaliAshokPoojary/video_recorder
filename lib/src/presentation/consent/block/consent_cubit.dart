import 'package:flutter_bloc/flutter_bloc.dart';
import 'consent_state.dart';

class ConsentCubit extends Cubit<ConsentState> {
  ConsentCubit() : super(const ConsentState());

  void toggleCamera(bool value) => emit(state.copyWith(cameraConsent: value));
  void togglePolicy(bool value) => emit(state.copyWith(policyAccepted: value));
}