import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CompressionService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.video_recorder/video_compression',
  );

  Future<bool> compressVideo(String inputPath, String outputPath) async {
    final result = await _channel.invokeMethod<bool>('compressVideo', {
      'inputPath': inputPath,
      'outputPath': outputPath,
    });

    return result ?? false;
  }

  Future<String> compressForUpload(String inputPath) async {
    final source = File(inputPath);
    if (!await source.exists()) {
      throw ArgumentError('Input file does not exist: $inputPath');
    }

    final appDir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory(p.join(appDir.path, 'exam_recordings'));
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    final outputPath = p.join(
      recordingsDir.path,
      'compressed_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    final success = await compressVideo(inputPath, outputPath);
    if (!success) {
      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        await outputFile.delete();
      }
      throw StateError('Compression failed for file: $inputPath');
    }

    final outputFile = File(outputPath);
    if (!await outputFile.exists() || await outputFile.length() == 0) {
      throw StateError('Compression failed: output file invalid.');
    }

    return outputPath;
  }
}
