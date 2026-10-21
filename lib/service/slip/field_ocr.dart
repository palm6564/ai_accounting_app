// Directory: lib/service/slip/
// File: field_ocr.dart

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// อ่านข้อความจากภาพที่ตัดมาแล้ว 1 ช่อง
abstract class FieldOcr {
  /// [thai] = ช่องนี้มีอักษรไทย (ชื่อ ธนาคาร วันที่แบบมีเดือนไทย)
  Future<String?> read(
    Uint8List crop, {
    required bool thai,
    bool multiline = false,
  });
}

/// OCR ในเครื่อง: ML Kit (latin) สำหรับตัวเลข/อังกฤษ, Tesseract (tha+eng) สำหรับช่องที่มีอักษรไทย
/// ไม่มีการเรียกบริการภายนอกใดๆ
class LocalFieldOcr implements FieldOcr {
  LocalFieldOcr({this.useTesseractForThai = true});

  final bool useTesseractForThai;
  bool _tesseractBroken = false;

  @override
  Future<String?> read(
    Uint8List crop, {
    required bool thai,
    bool multiline = false,
  }) async {
    final file = await _writeTemp(crop);
    try {
      if (thai && useTesseractForThai && !_tesseractBroken) {
        try {
          final text = await FlutterTesseractOcr.extractText(
            file.path,
            language: 'tha+eng',
            args: <String, String>{
              'psm': multiline ? '6' : '7',
              'preserve_interword_spaces': '1',
            },
          );
          final cleaned = text.trim();
          if (cleaned.isNotEmpty) return cleaned;
        } catch (error) {
          // ไม่มี tha.traineddata ใน assets/tessdata ฯลฯ → ไม่ลองซ้ำทุกช่อง
          _tesseractBroken = true;
          debugPrint('Tesseract ใช้ไม่ได้ (ตรวจ assets/tessdata/tha.traineddata): $error');
        }
      }
      return await _mlKit(file);
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  Future<String?> _mlKit(File file) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(file.path),
      );
      final text = result.text.trim();
      return text.isEmpty ? null : text;
    } catch (error) {
      debugPrint('ML Kit อ่านช่องไม่สำเร็จ: $error');
      return null;
    } finally {
      await recognizer.close();
    }
  }

  static int _counter = 0;

  Future<File> _writeTemp(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/slip_field_${_counter++}.png');
    return file.writeAsBytes(bytes, flush: true);
  }
}

/// ตัดภาพตามกล่องที่ตรวจเจอ (เผื่อขอบเล็กน้อย) และขยายช่องที่เตี้ยเกินไปให้ OCR อ่านง่าย
Uint8List? cropField(
  img.Image source, {
  required double cx,
  required double cy,
  required double width,
  required double height,
  double scale = 1.0,
  int pad = 6,
}) {
  final left = ((cx - width / 2) * scale).round() - pad;
  final top = ((cy - height / 2) * scale).round() - pad;
  final x = left.clamp(0, source.width - 1);
  final y = top.clamp(0, source.height - 1);
  final w = ((width * scale).round() + pad * 2).clamp(1, source.width - x);
  final h = ((height * scale).round() + pad * 2).clamp(1, source.height - y);
  if (w < 4 || h < 4) return null;
  var crop = img.copyCrop(source, x: x, y: y, width: w, height: h);
  if (crop.height < 64) {
    crop = img.copyResize(
      crop,
      height: 64,
      interpolation: img.Interpolation.cubic,
    );
  }
  return Uint8List.fromList(img.encodePng(crop));
}
