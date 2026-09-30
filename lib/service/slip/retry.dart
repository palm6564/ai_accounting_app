// Directory: lib/service/slip/
// File: retry.dart

import 'dart:async';

import 'slip_config.dart';

const List<String> _retryableMarkers = <String>[
  '429',
  '500',
  '502',
  '503',
  '504',
  'unavailable',
  'resource_exhausted',
  'resource exhausted',
  'overloaded',
  'high demand',
  'deadline',
  'timeout',
  'timed out',
  'socketexception',
];

/// error ชั่วคราว (โควตาเต็ม, high demand, เซิร์ฟเวอร์ล่ม, หมดเวลา) ที่คุ้มลองใหม่
bool isRetryable(Object error) {
  final message = error.toString().toLowerCase();
  return _retryableMarkers.any(message.contains);
}

/// เรียก [action] ซ้ำเมื่อเจอ error ชั่วคราว รอ 2, 4, 8 วินาที รวม [maxAttempts] ครั้ง
/// error อื่น (เช่น key ผิด, คำขอผิดรูปแบบ) โยนขึ้นไปทันที
Future<T> withRetry<T>(
  Future<T> Function() action, {
  int maxAttempts = SlipConfig.maxAttempts,
  Future<void> Function(Duration)? sleep,
}) async {
  final wait = sleep ?? (Duration d) => Future<void>.delayed(d);
  for (var attempt = 0; ; attempt++) {
    try {
      return await action();
    } catch (error) {
      if (attempt >= maxAttempts - 1 || !isRetryable(error)) rethrow;
      await wait(Duration(seconds: 2 << attempt));
    }
  }
}
