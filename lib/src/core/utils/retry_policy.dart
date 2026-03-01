import 'dart:async';

Future<T> withRetry<T>({
  required Future<T> Function() action,
  int maxAttempts = 3,
  Duration initialDelay = const Duration(seconds: 2),
  Duration? delayFactor,
}) async {
  var attempt = 0;
  var delay = delayFactor ?? initialDelay;
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
