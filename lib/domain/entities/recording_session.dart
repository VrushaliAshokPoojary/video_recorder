class RecordingSession {
  RecordingSession({
    required this.examId,
    required this.rawVideoPath,
    this.compressedVideoPath,
    this.startedAt,
    this.endedAt,
  });

  final String examId;
  final String rawVideoPath;
  final String? compressedVideoPath;
  final DateTime? startedAt;
  final DateTime? endedAt;

  RecordingSession copyWith({
    String? examId,
    String? rawVideoPath,
    String? compressedVideoPath,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return RecordingSession(
      examId: examId ?? this.examId,
      rawVideoPath: rawVideoPath ?? this.rawVideoPath,
      compressedVideoPath: compressedVideoPath ?? this.compressedVideoPath,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}
