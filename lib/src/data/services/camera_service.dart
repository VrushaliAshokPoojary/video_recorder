import 'dart:io';

import 'package:camera/camera.dart';
import '../../core/errors/proctoring_exception.dart';
import 'recording_storage_service.dart';

/// Silent camera recorder used by the proctoring workflow.
///
/// Stealth implementation detail:
/// - We initialize [CameraController] and start recording directly.
/// - We do NOT expose a preview widget to the presentation layer.
/// - Since no [CameraPreview] is mounted, candidates never see camera feed,
///   keeping the exam UI clean and responsive.
class CameraService {
  CameraService({required RecordingStorageService recordingStorageService})
    : _recordingStorageService = recordingStorageService;

  final RecordingStorageService _recordingStorageService;
  CameraController? _controller;
  bool _isRecording = false;

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
    final copied = await source.copy(_recordingStorageService.rawOutputPathForNow());
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
