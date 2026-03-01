import 'dart:io';

import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:path/path.dart' as p;

import '../../core/config/app_config.dart';

class CompressionService {
  Future<String> compressForUpload(String inputPath) async {
    final source = File(inputPath);
    if (!await source.exists()) {
      throw ArgumentError('Input file does not exist: $inputPath');
    }

    final parent = source.parent.path;
    final outputPath = p.join(
      parent,
      'compressed_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    // Temporal efficiency goal:
    // - We keep duration unchanged, but aggressively tune bitrate and GOP.
    // - Lower bitrate (~50% of typical high-quality mobile output) can produce
    //   an approximate "60 seconds stored like 30-second size" effect.
    // - CRF + maxrate + bufsize protects quality variance while shrinking size.
    final command = [
      '-i',
      '"$inputPath"',
      '-c:v',
      'libx264',
      '-preset',
      'veryfast',
      '-r',
      '${AppConfig.targetFps}',
      '-b:v',
      '${AppConfig.compressionVideoBitrateKbps}k',
      '-maxrate',
      '${AppConfig.compressionVideoBitrateKbps}k',
      '-bufsize',
      '${AppConfig.compressionVideoBitrateKbps * 2}k',
      '-g',
      '${AppConfig.targetFps * 2}',
      '-crf',
      '28',
      '-c:a',
      'aac',
      '-b:a',
      '${AppConfig.compressionAudioBitrateKbps}k',
      '-movflags',
      '+faststart',
      '"$outputPath"',
      '-y',
    ].join(' ');

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (returnCode == null || !returnCode.isValueSuccess()) {
      throw StateError('Compression failed. FFmpeg return code: $returnCode');
    }

    return outputPath;
  }
}
