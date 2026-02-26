class ProctoringResult {
  const ProctoringResult({
    required this.originalPath,
    required this.compressedPath,
    required this.uploadId,
    required this.originalBytes,
    required this.compressedBytes,
  });

  final String originalPath;
  final String compressedPath;
  final String uploadId;
  final int originalBytes;
  final int compressedBytes;

  double get compressionRatio {
    if (originalBytes == 0) return 0;
    return compressedBytes / originalBytes;
  }
}
