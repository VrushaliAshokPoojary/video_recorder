import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/errors/proctoring_exception.dart';

class CameraService {
  CameraController? _controller;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<void> ensurePermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
    ].request();

    final denied = statuses.entries.where((e) => !e.value.isGranted).toList();
    if (denied.isNotEmpty) {
      throw ProctoringException(
        'Camera and microphone permissions are required to start the exam.',
      );
    }
  }

  /// Starts front-camera recording without attaching any preview widget to the exam UI.
  /// Because no preview is mounted in the widget tree, recording stays visually stealth.
  Future<void> startSilentRecording() async {
    if (_isRecording) {
      throw ProctoringException('Recording is already in progress.');
    }

    await ensurePermissions();

    final cameras = await availableCameras();
    final front = cameras.where((c) => c.lensDirection == CameraLensDirection.front).firstOrNull;

    if (front == null) {
      throw ProctoringException('Front camera not available on this device.');
    }

    final controller = CameraController(
      front,
      ResolutionPreset.max,
      fps: 30,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await controller.initialize();
    await controller.prepareForVideoRecording();
    await controller.startVideoRecording();

    _controller = controller;
    _isRecording = true;
  }

  Future<String> stopRecordingAndPersist() async {
    if (_controller == null || !_isRecording) {
      throw ProctoringException('No active recording to stop.');
    }

    final recording = await _controller!.stopVideoRecording();
    _isRecording = false;

    final appDocDir = await getApplicationDocumentsDirectory();
    final rawDir = Directory(p.join(appDocDir.path, 'exam_recordings', 'raw'));
    await rawDir.create(recursive: true);
    final fileName = 'raw_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final targetPath = p.join(rawDir.path, fileName);

    await File(recording.path).copy(targetPath);

    await _controller?.dispose();
    _controller = null;
    return targetPath;
  }

  Future<void> pauseIfNeeded() async {
    if (_controller != null && _isRecording && _controller!.value.isRecordingVideo) {
      await _controller!.pauseVideoRecording();
    }
  }

  Future<void> resumeIfNeeded() async {
    if (_controller != null && _isRecording && _controller!.value.isRecordingPaused) {
      await _controller!.resumeVideoRecording();
    }
  }

  Future<void> dispose() async {
    if (_controller != null) {
      if (_isRecording) {
        await _controller!.stopVideoRecording();
      }
      await _controller!.dispose();
    }
    _controller = null;
    _isRecording = false;
  }
}
