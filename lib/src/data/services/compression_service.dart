import 'dart:io';
import 'dart:isolate';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/proctoring_constants.dart';
import '../../core/errors/proctoring_exception.dart';

class CompressionResult {
  const CompressionResult({required this.outputPath, required this.outputSize});

  final String outputPath;
  final int outputSize;
}

class CompressionService {
  /// Compresses the full-duration recording by reducing bitrate/buffer settings
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

    final outputPath = p.join(
      compressedDir.path,
      'compressed_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    final command = [
      '-y',
      '-i',
      inputPath,
      '-c:v',
      'libx264',
      '-preset',
      'veryfast',
      '-r',
      '${ProctoringConstants.targetFrameRate}',
      '-b:v',
      '${ProctoringConstants.maxBitrate}',
      '-maxrate',
      '${ProctoringConstants.maxBitrate}',
      '-bufsize',
      '${ProctoringConstants.maxBitrate * 2}',
      '-c:a',
      'aac',
      '-b:a',
      '96k',
      outputPath,
    ].join(' ');

    await Isolate.run(() async {
      final session = await FFmpegKit.execute(command);
      final code = await session.getReturnCode();
      if (code == null || !code.isValueSuccess()) {
        final logs = await session.getAllLogsAsString();
        throw ProctoringException('Compression failed: $logs');
      }
    });

    final outputFile = File(outputPath);
    final outputSize = await outputFile.length();

    await _saveDeveloperCopy(outputFile);

    return CompressionResult(outputPath: outputPath, outputSize: outputSize);
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
