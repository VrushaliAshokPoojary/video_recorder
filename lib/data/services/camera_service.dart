import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';

class CameraService {
  CameraController? _controller;
  String? _rawRecordingPath;

  bool get isRecording => _controller?.value.isRecordingVideo ?? false;

  Future<void> initializeFrontCamera() async {
    if (_controller != null) {
      return;
    }

    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    // We initialize the camera without rendering CameraPreview in the widget
    // tree. That enables stealth recording while keeping exam UI clean.
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

  Future<String> startRecording() async {
    final controller = _controller;
    if (controller == null) {
      throw StateError('Camera is not initialized.');
    }

    if (controller.value.isRecordingVideo) {
      throw StateError('Recording already in progress.');
    }

    await controller.startVideoRecording();

    final rootDir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory(p.join(rootDir.path, 'exam_recordings'));
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    // The camera plugin writes to temp while recording. We keep a deterministic
    // output path to move it at stop time.
    _rawRecordingPath = p.join(
      recordingsDir.path,
      'raw_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    return _rawRecordingPath!;
  }

  Future<String> stopRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isRecordingVideo) {
      throw StateError('No active recording to stop.');
    }

    final file = await controller.stopVideoRecording();
    final outputPath = _rawRecordingPath ?? file.path;

    if (file.path != outputPath) {
      final moved = await File(file.path).copy(outputPath);
      await File(file.path).delete();
      return moved.path;
    }

    return outputPath;
  }

  Future<void> ensureCaptureQuality() async {
    final controller = _controller;
    if (controller == null) return;

    final previewSize = controller.value.previewSize;
    if (previewSize == null) return;

    final width = previewSize.width;
    final height = previewSize.height;
    if (width < AppConfig.minCaptureWidth ||
        height < AppConfig.minCaptureHeight) {
      throw StateError(
        'Capture resolution below minimum requirement (1080p).',
      );
    }
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
