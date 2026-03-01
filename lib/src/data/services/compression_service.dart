import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

import '../../core/constants/proctoring_constants.dart';
import '../../core/errors/proctoring_exception.dart';

class CompressionResult {
  const CompressionResult({required this.outputPath, required this.outputSize});

  final String outputPath;
  final int outputSize;
}

class CompressionService {
  /// Compresses the full-duration recording by reducing bitrate/quality profile
  /// instead of trimming time, preserving exam evidence continuity.
  Future<CompressionResult> compressForUpload(String inputPath) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw ProctoringException('Input video does not exist: $inputPath');
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final compressedDir = Directory(
      p.join(appDocDir.path, 'exam_recordings', 'compressed'),
    );
    await compressedDir.create(recursive: true);

    final mediaInfo = await VideoCompress.compressVideo(
      inputPath,
      quality: _qualityFromTarget(),
      includeAudio: true,
      frameRate: ProctoringConstants.targetFrameRate,
      deleteOrigin: false,
    );

    final compressedPath = mediaInfo?.path;
    if (compressedPath == null || compressedPath.isEmpty) {
      throw ProctoringException('Compression failed: no output file generated.');
    }

    final sourceCompressed = File(compressedPath);
    if (!await sourceCompressed.exists()) {
      throw ProctoringException('Compression failed: output file not found at $compressedPath');
    }

    final outputPath = p.join(
      compressedDir.path,
      'compressed_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    final outputFile = await sourceCompressed.copy(outputPath);
    final outputSize = await outputFile.length();

    await _saveDeveloperCopy(outputFile);

    // Ensure plugin temp files are cleaned up between sessions.
    await VideoCompress.deleteAllCache();

    return CompressionResult(outputPath: outputPath, outputSize: outputSize);
  }

  VideoQuality _qualityFromTarget() {
    // Balanced profile usually gives strong size reduction (~40-60%) on 1080p source
    // while keeping proctoring content readable.
    if (ProctoringConstants.maxBitrate <= 2 * 1024 * 1024) {
      return VideoQuality.MediumQuality;
    }
    return VideoQuality.DefaultQuality;
  }

  Future<void> _saveDeveloperCopy(File compressedFile) async {
    try {
      final devDir = Directory(
        p.join(Directory.current.path, 'developer_artifacts', 'recordings'),
      );
      await devDir.create(recursive: true);
      await compressedFile.copy(p.join(devDir.path, p.basename(compressedFile.path)));
    } catch (_) {
      // Developer mirror copy is best-effort only; mobile runtime may not allow project folder access.
    }
  }
}
