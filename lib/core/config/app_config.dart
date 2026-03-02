class AppConfig {
  const AppConfig._();

  static const String uploadEndpoint =
      'https://mock-api.example.com/v1/exams/upload';

  static const int minCaptureWidth = 1920;
  static const int minCaptureHeight = 1080;
  static const int targetFps = 30;

  // Approximate target: reduce bitrate to ~50% without changing duration.
  static const int compressionVideoBitrateKbps = 2200;
  static const int compressionAudioBitrateKbps = 96;
  static const int uploadChunkSizeBytes = 1024 * 1024; // 1 MB
  static const int maxUploadRetries = 3;
}
