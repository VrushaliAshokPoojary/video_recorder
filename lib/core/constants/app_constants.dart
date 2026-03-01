class AppConstants {
  const AppConstants._();

  static const String uploadEndpoint =
      'https://example-proctoring-api.com/api/v1/exams/upload';
  static const int defaultUploadChunkSizeBytes = 1024 * 1024 * 5;
  static const int uploadMaxRetries = 5;
  static const Duration uploadRetryBaseDelay = Duration(seconds: 2);
}
