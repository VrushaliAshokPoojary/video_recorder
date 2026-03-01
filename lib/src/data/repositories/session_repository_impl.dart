import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/session_repository.dart';

class SessionRepositoryImpl implements SessionRepository {
  @override
  Future<AuthSession?> loadCurrentSession() async {
    // TODO: Replace with secure storage/API response
    return null;
  }
}