abstract class ConsentRepository {
  Future<void> logConsent({
    required String examId,
    required String candidateId,
    required String appVersion,
    required String deviceHash,
  });
}
