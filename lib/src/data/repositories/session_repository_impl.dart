import 'package:uuid/uuid.dart';

import '../../core/constants/proctoring_constants.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/session_repository.dart';

class SessionRepositoryImpl implements SessionRepository {
  final Uuid _uuid = const Uuid();

  @override
  Future<AuthSession?> loadCurrentSession() async {
    final examId = ProctoringConstants.runtimeExamId;
    final candidateId = ProctoringConstants.runtimeCandidateId;
    final token = ProctoringConstants.runtimeAuthToken;

    if (examId == null || candidateId == null || token == null) {
      return null;
    }

    return AuthSession(
      examId: examId,
      candidateId: candidateId,
      token: token,
      expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
      uploadId: _uuid.v4(),
    );
  }
}
