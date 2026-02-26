class ProctoringException implements Exception {
  ProctoringException(this.message);

  final String message;

  @override
  String toString() => 'ProctoringException: $message';
}
