import 'dart:developer' as developer;
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
    dynamic progressSubscription;

    try {
      // Ensure no previous plugin job is left in-flight.
      await VideoCompress.cancelCompression();

      progressSubscription = VideoCompress.compressProgress$.subscribe((progress) {
        // Keeps progress callback consumed and useful for release diagnostics.
        developer.log('Compression progress: $progress%', name: 'CompressionService');
      });

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
        originalBytes: await _lengthWithRetry(input),
        compressedBytes: await _lengthWithRetry(exportedCompressed),
      );
    } on FileSystemException catch (e) {
      throw ProctoringException('Compression file error: ${e.message}');
    } finally {
      await _unsubscribeProgress(progressSubscription);
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
    } on FileSystemException catch (e) {
      if (_isPendingOperation(e)) {
        // Fallback: preserve proctoring flow even if export copy remains locked.
        return compressedFile;
      }
      rethrow;
    }
  }

  Future<File> _copyWithRetry({
    required File source,
    required String targetPath,
  }) async {
    FileSystemException? lastException;

    for (var attempt = 0; attempt < 20; attempt++) {
      try {
        final target = File(targetPath);
        if (await target.exists()) {
          await target.delete();
        }
        return await source.copy(targetPath);
      } on FileSystemException catch (e) {
        lastException = e;

        if (!_isPendingOperation(e)) {
          rethrow;
        }

        await Future<void>.delayed(
          Duration(milliseconds: 250 + (attempt * 150)),
        );
      }
    }

    throw lastException ??
        FileSystemException('Unable to copy compressed output.', targetPath);
  }

  Future<File> _waitForStableFile(String outputPath) async {
    final file = File(outputPath);

    var previousLength = -1;
    for (var attempt = 0; attempt < 40; attempt++) {
      try {
        if (await file.exists()) {
          final currentLength = await file.length();
          if (currentLength > 0 && currentLength == previousLength) {
            return file;
          }
          previousLength = currentLength;
        }
      } on FileSystemException catch (e) {
        if (!_isPendingOperation(e)) {
          rethrow;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    throw ProctoringException(
      'Compression failed: output file was not ready for access.',
    );
  }

  Future<int> _lengthWithRetry(File file) async {
    FileSystemException? lastException;

    for (var attempt = 0; attempt < 16; attempt++) {
      try {
        return await file.length();
      } on FileSystemException catch (e) {
        lastException = e;
        if (!_isPendingOperation(e)) {
          rethrow;
        }
        await Future<void>.delayed(
          Duration(milliseconds: 200 + (attempt * 120)),
        );
      }
    }

    throw lastException ??
        FileSystemException('Unable to read file length.', file.path);
  }

  bool _isPendingOperation(FileSystemException e) {
    final message = e.message.toLowerCase();
    return message.contains('async operation') ||
        message.contains('currently pending') ||
        message.contains('being used by another process') ||
        message.contains('resource busy');
  }

  Future<void> _unsubscribeProgress(dynamic subscription) async {
    if (subscription == null) return;

    try {
      final result = subscription.unsubscribe();
      if (result is Future) {
        await result;
      }
    } catch (_) {
      // Best effort: progress observer should not break compression flow.
    }
  }

  Future<void> _safeDeleteCache() async {
    try {
      await VideoCompress.deleteAllCache();
    } catch (_) {
      // Best effort only; cache cleanup should not break exam submission flow.
    }
  }
}
