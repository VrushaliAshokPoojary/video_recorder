import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../data/datasources/permission_datasource.dart';
import '../../data/repositories/proctoring_repository_impl.dart';
import '../../data/services/background_task_service.dart';
import '../../data/services/camera_service.dart';
import '../../data/services/compression_service.dart';
import '../../data/services/recording_storage_service.dart';
import '../../data/services/upload_service.dart';
import '../../domain/repositories/proctoring_repository.dart';
import '../../domain/usecases/end_exam_usecase.dart';
import '../../domain/usecases/start_exam_usecase.dart';
import '../../presentation/exam/exam_controller.dart';

class ServiceLocator {
  static final GetIt _getIt = GetIt.instance;

  static T get<T extends Object>() => _getIt.get<T>();

  static Future<void> setup() async {
    _getIt
      ..registerLazySingleton<Dio>(() => Dio())
      ..registerLazySingleton(PermissionDataSource.new)
      ..registerLazySingleton(RecordingStorageService.new)
      ..registerLazySingleton(() => CameraService(recordingStorageService: _getIt()))
      ..registerLazySingleton(
        () => CompressionService(recordingStorageService: _getIt()),
      )
      ..registerLazySingleton(() => UploadService(_getIt()))
      ..registerLazySingleton(BackgroundTaskService.new)
      ..registerLazySingleton<ProctoringRepository>(
        () => ProctoringRepositoryImpl(
          permissionDataSource: _getIt(),
          cameraService: _getIt(),
          compressionService: _getIt(),
          uploadService: _getIt(),
          backgroundTaskService: _getIt(),
        ),
      )
      ..registerLazySingleton(() => StartExamUseCase(_getIt()))
      ..registerLazySingleton(() => EndExamUseCase(_getIt()))
      ..registerFactory(
        () => ExamController(
          startExamUseCase: _getIt(),
          endExamUseCase: _getIt(),
          proctoringRepository: _getIt(),
        ),
      );

    await _getIt<RecordingStorageService>().initialize();
  }
}
