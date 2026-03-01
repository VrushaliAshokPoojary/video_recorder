import 'package:equatable/equatable.dart';

class ProctoringResult extends Equatable {
  const ProctoringResult({
    required this.rawVideoPath,
    required this.compressedVideoPath,
    required this.rawSizeBytes,
    required this.compressedSizeBytes,
    required this.uploadReference,
  });

  final String rawVideoPath;
  final String compressedVideoPath;
  final int rawSizeBytes;
  final int compressedSizeBytes;
  final String uploadReference;

  double get compressionRatio =>
      rawSizeBytes == 0 ? 0 : compressedSizeBytes / rawSizeBytes;

  @override
  List<Object?> get props => [
        rawVideoPath,
        compressedVideoPath,
        rawSizeBytes,
        compressedSizeBytes,
        uploadReference,
      ];
}
