import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Centralized recording storage layout used across camera + compression.
class RecordingStorageService {
  static const String folderName = 'video_recorder';
  late final Directory _rootDirectory;
  late final Directory _rawDirectory;
  late final Directory _compressedDirectory;

  Directory get rootDirectory => _rootDirectory;
  Directory get rawDirectory => _rawDirectory;
  Directory get compressedDirectory => _compressedDirectory;

  Future<void> initialize() async {
    final baseDirectory = await _resolveBaseDirectory();
    _rootDirectory = Directory(p.join(baseDirectory.path, folderName));
    _rawDirectory = Directory(p.join(_rootDirectory.path, 'raw'));
    _compressedDirectory = Directory(p.join(_rootDirectory.path, 'compressed'));

    if (!await _rawDirectory.exists()) {
      await _rawDirectory.create(recursive: true);
    }
    if (!await _compressedDirectory.exists()) {
      await _compressedDirectory.create(recursive: true);
    }
  }

  String rawOutputPathForNow() {
    return p.join(
      _rawDirectory.path,
      'raw_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
  }

  String compressedOutputPathForNow() {
    return p.join(
      _compressedDirectory.path,
      'compressed_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
  }

  String latestCompressedPath() {
    return p.join(_compressedDirectory.path, 'latest_compressed.mp4');
  }

  Future<Directory> _resolveBaseDirectory() async {
    if (Platform.isAndroid) {
      final publicDownloads = Directory('/storage/emulated/0/Download');
      if (await _isUsableDirectory(publicDownloads)) {
        return publicDownloads;
      }

      final external = await getExternalStorageDirectory();
      if (external != null) {
        return external;
      }
    }

    return getApplicationDocumentsDirectory();
  }

  Future<bool> _isUsableDirectory(Directory directory) async {
    try {
      if (!await directory.exists()) {
        return false;
      }

      final probe = File(
        p.join(
          directory.path,
          '.video_recorder_access_probe_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
      await probe.writeAsString('probe');
      if (await probe.exists()) {
        await probe.delete();
      }
      return true;
    } on FileSystemException {
      return false;
    }
  }
}
