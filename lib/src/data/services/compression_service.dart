import 'dart:io';

import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/errors/proctoring_exception.dart';

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
  /// Performs local temporal/bitrate optimization without trimming duration.
  ///
  /// ffmpeg strategy:
  /// - H.264 with slower preset for better compression efficiency.
  /// - 30fps enforced to keep playback smooth.
  /// - Target average bitrate lowered (~50% vs typical camera output).
  /// - AAC audio bitrate reduced to 96k.
  ///
  /// This keeps 60s of content at 60s length, but near size of a less
  /// efficient 30s clip by aggressive bitrate optimization.
  Future<CompressionResult> compress(String inputPath) async {
    final input = File(inputPath);
    if (!await input.exists()) {
      throw ProctoringException('Input recording file does not exist.');
    }

    final docs = await getApplicationDocumentsDirectory();
    final outPath = p.join(
      docs.path,
      'compressed_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    const command =
        '-y -i INPUT -vf "fps=30,scale=1920:1080:force_original_aspect_ratio=decrease" '
        '-c:v libx264 -preset slow -profile:v high -level 4.1 '
        '-b:v 2500k -maxrate 3000k -bufsize 5000k '
        '-c:a aac -b:a 96k -movflags +faststart OUTPUT';

    final normalized = command
        .replaceFirst('INPUT', '"$inputPath"')
        .replaceFirst('OUTPUT', '"$outPath"');

    final session = await FFmpegKit.execute(normalized);
    final rc = await session.getReturnCode();

    if (rc == null || !rc.isValueSuccess()) {
      throw ProctoringException('Compression failed with return code: $rc');
    }

    final compressed = File(outPath);
    return CompressionResult(
      path: compressed.path,
      originalBytes: await input.length(),
      compressedBytes: await compressed.length(),
    );
  }
}
