import 'dart:io';

import 'package:video_compress/video_compress.dart';

import '../../core/errors/proctoring_exception.dart';

class CompressionResult {
  const CompressionResult({
    required this.path,
    required this.originalBytes,
    required this.compressedBytes,
  });

  final String path;
  final int originalBytes;
  final int compressedBytes;
}

class CompressionService {
  /// Performs local bitrate-driven compression without cutting duration.
  ///
  /// We use [VideoCompress] with 720p profile + target frameRate 30 to
  /// significantly reduce output size while preserving timeline length.
  Future<CompressionResult> compress(String inputPath) async {
    final input = File(inputPath);
    if (!await input.exists()) {
      throw ProctoringException('Input recording file does not exist.');
    }

    final info = await VideoCompress.compressVideo(
      inputPath,
      quality: VideoQuality.Res1280x720Quality,
      frameRate: 30,
      includeAudio: true,
      deleteOrigin: false,
    );

    final outPath = info?.path;
    if (outPath == null) {
      throw ProctoringException('Compression failed: output path is null.');
    }

    final compressed = File(outPath);
    if (!await compressed.exists()) {
      throw ProctoringException('Compression failed: output file missing.');
    }

    return CompressionResult(
      path: compressed.path,
      originalBytes: await input.length(),
      compressedBytes: await compressed.length(),
    );
  }
}
