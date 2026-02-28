class ProctoringConstants {
  ProctoringConstants._();

  static const int minBitrate = 2 * 1024 * 1024; // 2 Mbps
  static const int maxBitrate = 4 * 1024 * 1024; // 4 Mbps target for 1080p
  static const int targetFrameRate = 30;
  static const int compressionScalePercent = 50;
  static const String uploadEndpoint =
      'https://mock-proctoring-api.example.com/v1/uploads/exam-video';
}
