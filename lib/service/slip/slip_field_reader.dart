// Directory: lib/service/slip/
// File: slip_field_reader.dart

import 'dart:typed_data';

import 'slip_models.dart';

/// ตัวอ่านสลิป 1 ใบ → ผลอ่านพร้อมคะแนน (Roboflow + OCR ในเครื่อง หรือเซิร์ฟเวอร์อ่านสลิปของเราเอง)
abstract class SlipFieldReader {
  /// ตั้งค่าครบพอจะเรียกใช้หรือยัง (ไม่ครบ = ข้ามไปใช้ regex ออฟไลน์)
  bool get isConfigured;

  /// ข้อความบอกวิธีตั้งค่า เมื่อ [isConfigured] เป็น false
  String get setupHint;

  /// สาเหตุที่อ่านไม่สำเร็จในครั้งล่าสุด
  List<String> get errors;

  /// null = อ่านไม่สำเร็จ (ดูสาเหตุใน [errors])
  Future<ScoredRead?> read(Uint8List bytes);
}
