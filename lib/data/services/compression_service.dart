import 'dart:io';

import 'package:video_compress/video_compress.dart';

import '../../core/config/app_config.dart';

class CompressionService {
  Future<String> compressForUpload(String inputPath) async {
    final source = File(inputPath);
    if (!await source.exists()) {
      throw ArgumentError('Input file does not exist: $inputPath');
    }

    // Device-native on-device compression.
    final result = await VideoCompress.compressVideo(
      inputPath,
      quality: VideoQuality.MediumQuality,
      frameRate: AppConfig.targetFps,
      includeAudio: true,
      deleteOrigin: false,
    );

    final outputPath = result?.path;
    if (outputPath == null || outputPath.isEmpty) {
      throw StateError('Compression failed: output path is null.');
    }

    // Keep plugin output path intact; repository handles robust archival copy.
    return outputPath;
  }
}
