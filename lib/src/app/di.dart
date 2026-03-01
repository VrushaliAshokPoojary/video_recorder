import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../data/datasources/proctoring_remote_data_source.dart';
import '../data/repositories/proctoring_repository_impl.dart';
import '../data/repositories/session_repository_impl.dart';
import '../data/services/camera_service.dart';
import '../data/services/compression_service.dart';
import '../data/services/consent_audit_service.dart';
import '../data/services/upload_service.dart';
import '../domain/repositories/proctoring_repository.dart';
import '../domain/repositories/session_repository.dart';
import '../domain/usecases/end_exam_usecase.dart';
import '../domain/usecases/start_exam_usecase.dart';
import '../presentation/exam/bloc/exam_controller.dart';
import '../presentation/session/session_controller.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  getIt
    ..registerLazySingleton<Dio>(
      () => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(minutes: 5),
        ),
      ),
    )
    ..registerLazySingleton<CameraService>(CameraService.new)
    ..registerLazySingleton<CompressionService>(CompressionService.new)
    ..registerLazySingleton<UploadService>(() => UploadService(getIt()))
    ..registerLazySingleton<ConsentAuditService>(() => ConsentAuditService(getIt()))
    ..registerLazySingleton<SessionRepository>(SessionRepositoryImpl.new)
    ..registerFactory(() => SessionController(getIt()))
    ..registerLazySingleton<ProctoringRemoteDataSource>(
      () => ProctoringRemoteDataSource(uploadService: getIt()),
    )
    ..registerLazySingleton<ProctoringRepository>(
      () => ProctoringRepositoryImpl(
        cameraService: getIt(),
        compressionService: getIt(),
        remoteDataSource: getIt(),
      ),
    )
    ..registerFactory(() => StartExamUseCase(getIt()))
    ..registerFactory(() => EndExamUseCase(getIt()))
    ..registerFactory(
      () => ExamController(
        startExamUseCase: getIt(),
        endExamUseCase: getIt(),
        consentAuditService: getIt(),
      ),
    );
}
