import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

/// Records from front camera without rendering preview in the widget tree.
///
/// Stealth implementation detail:
/// - The camera plugin requires initialization, but preview is optional.
/// - We initialize [CameraController] and call video recording APIs directly.
/// - Because no [CameraPreview] widget is built, there is no visible camera feed
///   on the exam screen.
class CameraService {
  CameraController? _controller;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<void> initialize() async {
    if (_controller != null) {
      return;
    }

    final cameras = await availableCameras();
    final CameraDescription frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      frontCamera,
      ResolutionPreset.max,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await controller.initialize();
    await controller.prepareForVideoRecording();
    _controller = controller;
  }

  Future<String> startRecording({required String examId}) async {
    final controller = _controller;
    if (controller == null) {
      throw StateError('CameraService not initialized.');
    }
    if (_isRecording) {
      throw StateError('A recording is already in progress.');
    }

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final Directory recordingsDir = Directory('${appDocDir.path}/exam_recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    final String outputPath =
        '${recordingsDir.path}/${examId}_${DateTime.now().millisecondsSinceEpoch}.mp4';

    await controller.startVideoRecording();
    _isRecording = true;

    return outputPath;
  }

  Future<String> stopRecording({required String fallbackPath}) async {
    final controller = _controller;
    if (controller == null) {
      throw StateError('CameraService not initialized.');
    }
    if (!_isRecording) {
      throw StateError('No active recording to stop.');
    }

    final XFile file = await controller.stopVideoRecording();
    _isRecording = false;

    final File recorded = File(file.path);
    final File destination = File(fallbackPath);
    if (recorded.path != destination.path) {
      await recorded.copy(destination.path);
      await recorded.delete();
    }

    return destination.path;
  }

  Future<void> dispose() async {
    _isRecording = false;
    await _controller?.dispose();
    _controller = null;
  }
}
