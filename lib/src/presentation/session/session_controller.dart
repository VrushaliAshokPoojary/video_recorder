import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/session_repository.dart';

class SessionState {
  const SessionState({
    this.session,
    this.loading = false,
    this.error,
  });

  final AuthSession? session;
  final bool loading;
  final String? error;

  bool get hasValidSession => session != null && !(session!.isExpired);

  SessionState copyWith({
    AuthSession? session,
    bool? loading,
    String? error,
  }) {
    return SessionState(
      session: session ?? this.session,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class SessionController extends Cubit<SessionState> {
  SessionController(this._sessionRepository) : super(const SessionState());

  final SessionRepository _sessionRepository;

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null));
    final session = await _sessionRepository.loadCurrentSession();

    if (session == null) {
      emit(
        const SessionState(
          loading: false,
          error:
              'Session is unavailable. Pass --dart-define=EXAM_ID, CANDIDATE_ID and AUTH_TOKEN.',
        ),
      );
      return;
    }

    if (session.isExpired) {
      emit(
        const SessionState(
          loading: false,
          error: 'Session expired. Please login again.',
        ),
      );
      return;
    }

    emit(SessionState(session: session, loading: false));
  }
}
