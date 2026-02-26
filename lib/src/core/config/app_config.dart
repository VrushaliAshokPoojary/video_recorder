class AppConfig {
  static const String uploadEndpoint =
      'https://mock.exam-proctor.example.com/api/v1/proctoring/upload';
  static const int maxUploadRetries = 3;
  static const Duration retryBackoff = Duration(seconds: 2);
}
