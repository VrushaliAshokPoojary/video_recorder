import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
      final exportedCompressed = await _exportForEasyAccess(compressed);

      return CompressionResult(
        path: exportedCompressed.path,
        originalBytes: await input.length(),
        compressedBytes: await exportedCompressed.length(),
      );
    } on FileSystemException catch (e) {
      throw ProctoringException('Compression file error: ${e.message}');
    } finally {
      _isCompressing = false;
    }
  }

  Future<File> _exportForEasyAccess(File compressedFile) async {
    try {
      final baseDir =
          await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final exportsDir = Directory(p.join(baseDir.path, 'compressed_videos'));
      if (!await exportsDir.exists()) {
        await exportsDir.create(recursive: true);
      }

      final timestampedOutput = p.join(
        exportsDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      final savedCopy = await _copyFileWithRetry(
        source: compressedFile,
        destinationPath: timestampedOutput,
      );

      final latestOutput = p.join(exportsDir.path, 'latest_compressed.mp4');
      await _copyFileWithRetry(
        source: savedCopy,
        destinationPath: latestOutput,
      );

      return savedCopy;
    } on FileSystemException {
      // Fallback: preserve proctoring flow even if export copy fails.
      return compressedFile;
    }
  }

  Future<File> _copyFileWithRetry({
    required File source,
    required String destinationPath,
  }) async {
    const maxAttempts = 5;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final destination = File(destinationPath);
        if (await destination.exists()) {
          await destination.delete();
        }
        return await source.copy(destinationPath);
      } on FileSystemException {
        if (attempt == maxAttempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
      }
    }

    throw ProctoringException('Copy failed unexpectedly.');
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
