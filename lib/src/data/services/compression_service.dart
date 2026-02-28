import 'dart:async';
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
  bool _isCompressing = false;

  /// Performs local bitrate-driven compression without cutting duration.
  ///
  /// We use [VideoCompress] with 720p profile + target frameRate 30 to
  /// significantly reduce output size while preserving timeline length.
  Future<CompressionResult> compress(String inputPath) async {
    if (_isCompressing) {
      throw ProctoringException(
        'Compression is already in progress. Please wait for completion.',
      );
    }

    final input = File(inputPath);
    if (!await input.exists()) {
      throw ProctoringException('Input recording file does not exist.');
    }

    _isCompressing = true;
    try {
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

      final compressed = await _waitForStableFile(outPath);

      return CompressionResult(
        path: compressed.path,
        originalBytes: await input.length(),
        compressedBytes: await compressed.length(),
      );
    } on FileSystemException catch (e) {
      throw ProctoringException('Compression file error: ${e.message}');
    } finally {
      _isCompressing = false;
    }
  }

  Future<File> _waitForStableFile(String outputPath) async {
    final file = File(outputPath);

    var previousLength = -1;
    for (var attempt = 0; attempt < 10; attempt++) {
      if (await file.exists()) {
        final currentLength = await file.length();
        if (currentLength > 0 && currentLength == previousLength) {
          return file;
        }
        previousLength = currentLength;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    throw ProctoringException(
      'Compression failed: output file was not ready for access.',
    );
  }
}
