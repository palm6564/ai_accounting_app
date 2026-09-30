// Directory: lib/service/slip/
// File: ai_types.dart

import 'dart:typed_data';

/// คำขอเรียก Gemini 1 ครั้ง (แนบภาพได้) แยกเป็นชนิดกลางเพื่อให้ทดสอบตรรกะได้โดยไม่ต้องต่อเน็ต
class GeminiRequest {
  const GeminiRequest({
    required this.model,
    required this.prompt,
    this.image,
    this.mimeType,
  });

  final String model;
  final String prompt;
  final Uint8List? image;
  final String? mimeType;
}

/// เรียก Gemini แล้วคืนข้อความคำตอบ (โยน error ได้ ผู้เรียกเป็นคนจัดการ)
typedef GeminiCall = Future<String?> Function(GeminiRequest request);
