import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:video_compress/video_compress.dart';

import '../../core/config/app_config.dart';

class CompressionService {
  Future<String> compressForUpload(String inputPath) async {
    final source = File(inputPath);
    if (!await source.exists()) {
      throw ArgumentError('Input file does not exist: $inputPath');
    }

    // Equivalent replacement for ffmpeg_kit:
    // - `video_compress` performs device-native transcoding completely on-device.
    // - Medium quality usually yields a substantial size drop (~40-60%) while
    //   preserving readability needed for proctoring evidence.
    // - Duration is not trimmed; only bitrate/encoding profile is optimized.
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

    // Store compressed file in the same recording directory with deterministic
    // naming, then clear plugin cache artifacts.
    final targetPath = p.join(
      source.parent.path,
      'compressed_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    final compressedFile = File(outputPath);
    final moved = await compressedFile.copy(targetPath);
    if (outputPath != targetPath && await compressedFile.exists()) {
      await compressedFile.delete();
    }

    await VideoCompress.cancelCompression();

    return moved.path;
  }
}
