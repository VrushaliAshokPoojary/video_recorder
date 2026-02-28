import 'dart:async';

Future<T> withRetry<T>({
  required Future<T> Function() action,
  int maxAttempts = 3,
  Duration initialDelay = const Duration(seconds: 2),
}) async {
  var attempt = 0;
  var delay = initialDelay;
  while (true) {
    attempt++;
    try {
      return await action();
    } catch (_) {
      if (attempt >= maxAttempts) rethrow;
      await Future<void>.delayed(delay);
      delay *= 2;
    }
  }
}
