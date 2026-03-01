import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/session_repository.dart';

class SessionState {
  const SessionState({this.session, this.error});
  final AuthSession? session;
  final String? error;
}

class SessionController extends Cubit<SessionState> {
  SessionController(this._repository) : super(const SessionState());

  final SessionRepository _repository;

  Future<void> load() async {
    final session = await _repository.loadCurrentSession();
    emit(SessionState(session: session));
  }
}