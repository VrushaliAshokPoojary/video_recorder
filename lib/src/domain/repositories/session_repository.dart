import '../entities/auth_session.dart';

abstract class SessionRepository {
  Future<AuthSession?> loadCurrentSession();
}