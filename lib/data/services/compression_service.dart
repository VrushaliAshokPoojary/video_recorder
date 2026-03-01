import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffprobe_kit.dart';
import 'package:path_provider/path_provider.dart';

/// Handles local, on-device compression using ffmpeg.
///
/// Temporal-equivalent optimization here means reducing bitrate to ~50%
/// while preserving full duration (no trimming).
class CompressionService {
  Future<String> compressVideo(String inputPath, {String? examId}) async {
    final int sourceBitrate = await _readBitrate(inputPath);
    final int targetBitrate = sourceBitrate > 0
        ? (sourceBitrate * 0.5).round()
        : 2 * 1024 * 1024; // fallback ~2Mbps

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final Directory compressedDir =
        Directory('${appDocDir.path}/exam_recordings/compressed');
    if (!await compressedDir.exists()) {
      await compressedDir.create(recursive: true);
    }

    final String outputPath =
        '${compressedDir.path}/${examId ?? 'exam'}_${DateTime.now().millisecondsSinceEpoch}_compressed.mp4';

    final String command = [
      '-i "$inputPath"',
      '-c:v libx264',
      '-preset veryfast',
      '-b:v $targetBitrate',
      '-maxrate $targetBitrate',
      '-bufsize ${targetBitrate * 2}',
      '-c:a aac',
      '-b:a 96k',
      '-movflags +faststart',
      '-y "$outputPath"',
    ].join(' ');

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (returnCode == null || !returnCode.isValueSuccess()) {
      final logs = await session.getLogsAsString();
      throw StateError('Compression failed: $logs');
    }

    return outputPath;
  }

  Future<int> _readBitrate(String inputPath) async {
    final infoSession =
        await FFprobeKit.getMediaInformation('"$inputPath"');
    final info = infoSession.getMediaInformation();
    final bitRateRaw = info?.getBitrate();
    if (bitRateRaw == null) {
      return 0;
    }
    return int.tryParse(bitRateRaw) ?? 0;
  }
}
