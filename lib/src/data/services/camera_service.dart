import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/errors/proctoring_exception.dart';

/// Silent camera recorder used by the proctoring workflow.
///
/// Stealth implementation detail:
/// - We initialize [CameraController] and start recording directly.
/// - We do NOT expose a preview widget to the presentation layer.
/// - Since no [CameraPreview] is mounted, candidates never see camera feed,
///   keeping the exam UI clean and responsive.
class CameraService {
  CameraController? _controller;
  bool _isRecording = false;
  String? _currentRecordingPath;

  bool get isRecording => _isRecording;

  Future<void> startStealthRecording() async {
    if (_isRecording) {
      throw ProctoringException('Recording is already in progress.');
    }

    final cameras = await availableCameras();
    final front = cameras.where(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );

    if (front.isEmpty) {
      throw ProctoringException('Front camera not available.');
    }

    _controller = CameraController(
      front.first,
      ResolutionPreset.max,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    await _controller!.prepareForVideoRecording();
    await _controller!.startVideoRecording();
    _isRecording = true;
  }

  Future<String> stopRecording() async {
    if (!_isRecording || _controller == null) {
      throw ProctoringException('No active recording to stop.');
    }

    final recording = await _controller!.stopVideoRecording();
    final source = File(recording.path);
    final appDir = await getApplicationDocumentsDirectory();
    final outputPath = p.join(
      appDir.path,
      'raw_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    final copied = await source.copy(outputPath);
    _currentRecordingPath = copied.path;
    _isRecording = false;

    await _controller?.dispose();
    _controller = null;

    return copied.path;
  }

  Future<void> restartIfNeeded() async {
    if (!_isRecording) {
      await startStealthRecording();
    }
  }

  Future<void> dispose() async {
    if (_isRecording) {
      await stopRecording();
    }
    await _controller?.dispose();
    _controller = null;
  }
}
