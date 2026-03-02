import 'dart:io';

import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';

class CompressionService {
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

    // 2x fast-forward compression while preserving full content chronology.
    // - setpts=0.5*PTS: halves duration by doubling playback speed.
    // - atempo=2.0: keeps audio synced to the speed-up.
    final command = [
      '-y',
      '-i',
      '"$inputPath"',
      '-vf',
      '"setpts=0.5*PTS"',
      '-r',
      AppConfig.targetFps.toString(),
      '-c:v',
      'libx264',
      '-b:v',
      '${AppConfig.compressionVideoBitrateKbps}k',
      '-preset',
      'veryfast',
      '-crf',
      '24',
      '-c:a',
      'aac',
      '-b:a',
      '${AppConfig.compressionAudioBitrateKbps}k',
      '-af',
      '"atempo=2.0"',
      '-movflags',
      '+faststart',
      '"$outputPath"',
    ].join(' ');

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (returnCode == null || !returnCode.isValueSuccess()) {
      if (await File(outputPath).exists()) {
        await File(outputPath).delete();
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
