import 'dart:io';

import 'package:video_compress/video_compress.dart';

import '../../core/errors/proctoring_exception.dart';
import 'recording_storage_service.dart';

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
  CompressionService({required RecordingStorageService recordingStorageService})
    : _recordingStorageService = recordingStorageService;

  final RecordingStorageService _recordingStorageService;
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
      // Ensure no previous plugin job is left in-flight.
      await VideoCompress.cancelCompression();

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
      await _safeDeleteCache();
      _isCompressing = false;
    }
  }

  Future<File> _exportForEasyAccess(File compressedFile) async {
    try {
      final savedCopy = await _copyWithRetry(
        source: compressedFile,
        targetPath: _recordingStorageService.compressedOutputPathForNow(),
      );

      await _copyWithRetry(
        source: savedCopy,
        targetPath: _recordingStorageService.latestCompressedPath(),
      );

      return savedCopy;
    } on FileSystemException {
      // Fallback: preserve proctoring flow even if export copy fails.
      return compressedFile;
    }
  }

  Future<File> _copyWithRetry({
    required File source,
    required String targetPath,
  }) async {
    FileSystemException? lastException;

    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        return await source.copy(targetPath);
      } on FileSystemException catch (e) {
        lastException = e;
        final message = e.message.toLowerCase();
        final isPendingOperation = message.contains('async operation') ||
            message.contains('currently pending');

        if (!isPendingOperation) {
          rethrow;
        }

        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }

    throw lastException ??
        FileSystemException('Unable to copy compressed output.', targetPath);
  }

  Future<File> _waitForStableFile(String outputPath) async {
    final file = File(outputPath);

    var previousLength = -1;
    for (var attempt = 0; attempt < 20; attempt++) {
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

  Future<void> _safeDeleteCache() async {
    try {
      await VideoCompress.deleteAllCache();
    } catch (_) {
      // Best effort only; cache cleanup should not break exam submission flow.
    }
  }
}
