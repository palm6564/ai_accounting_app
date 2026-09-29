// ไฟล์ widget_test.dart ใน directory test: ชุดทดสอบ Widget ใช้ WidgetTester ตรวจ UI และการโต้ตอบ
// Directory: test/
// File: widget_test.dart
// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_accounting_app/service/auth_service.dart';

void main() {
  group('AuthService.isAtLeast18', () {
    final today = DateTime(2026, 9, 29);

    test('accepts the exact 18th birthday', () {
      expect(
        AuthService.isAtLeast18(DateTime(2008, 9, 29), now: today),
        isTrue,
      );
    });

    test('rejects a date one day short of 18', () {
      expect(
        AuthService.isAtLeast18(DateTime(2008, 9, 30), now: today),
        isFalse,
      );
    });

    test('rejects a future date of birth', () {
      expect(
        AuthService.isAtLeast18(DateTime(2027, 1, 1), now: today),
        isFalse,
      );
    });
  });
}
