import 'package:flutter_test/flutter_test.dart';

import 'package:video_recorder/src/core/utils/retry_policy.dart';

void main() {
  test('withRetry returns immediately on first success', () async {
    var calls = 0;

    final result = await withRetry(
      maxAttempts: 3,
      action: () async {
        calls++;
        return 'ok';
      },
    );

    expect(result, 'ok');
    expect(calls, 1);
  });

  test('withRetry retries and eventually succeeds', () async {
    var calls = 0;

    final result = await withRetry(
      maxAttempts: 3,
      delayFactor: const Duration(milliseconds: 1),
      action: () async {
        calls++;
        if (calls < 3) {
          throw Exception('temporary');
        }
        return 42;
      },
    );

    expect(result, 42);
    expect(calls, 3);
  });

  test('withRetry throws after max attempts', () async {
    var calls = 0;

    expect(
      () => withRetry(
        maxAttempts: 2,
        delayFactor: const Duration(milliseconds: 1),
        action: () async {
          calls++;
          throw Exception('always fail');
        },
      ),
      throwsException,
    );

    expect(calls, 2);
  });
}
