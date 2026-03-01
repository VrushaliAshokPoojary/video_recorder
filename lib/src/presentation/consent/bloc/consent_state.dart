class ConsentState {
  const ConsentState({
    this.cameraConsent = false,
    this.policyAccepted = false,
  });

  final bool cameraConsent;
  final bool policyAccepted;

  bool get canStartExam => cameraConsent && policyAccepted;

  ConsentState copyWith({bool? cameraConsent, bool? policyAccepted}) {
    return ConsentState(
      cameraConsent: cameraConsent ?? this.cameraConsent,
      policyAccepted: policyAccepted ?? this.policyAccepted,
    );
  }
}
