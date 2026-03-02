import 'dart:io';

import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ScreenRecordingService {
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<void> startRecording() async {
    if (_isRecording) {
      throw StateError('Screen recording already in progress.');
    }

    // Raw name is intentionally temporary; repository will compress/process and
    // archive final output to canonical scr_rec.mp4.
    await FlutterScreenRecording.startRecordScreen(
      'Exam proctoring is recording',
      'Screen capture in progress',
    );

    _isRecording = true;
  }

  Future<String> stopRecording() async {
    if (!_isRecording) {
      throw StateError('No active screen recording to stop.');
    }

    final outputPath = await FlutterScreenRecording.stopRecordScreen;
    _isRecording = false;

    if (outputPath == null || outputPath.isEmpty) {
      throw StateError('Screen recording failed: output path is null.');
    }

    final source = File(outputPath);
    if (!await source.exists()) {
      throw StateError('Screen recording file missing: $outputPath');
    }

    final appDir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory(p.join(appDir.path, 'exam_recordings'));
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    final localRawPath = p.join(
      recordingsDir.path,
      'scr_raw_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    if (source.path == localRawPath) {
      return localRawPath;
    }

    final copied = await source.copy(localRawPath);
    if (source.path != copied.path) {
      await source.delete();
    }
    return copied.path;
  }
}
