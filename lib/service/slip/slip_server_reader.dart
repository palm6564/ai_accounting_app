// Directory: lib/service/slip/
// File: slip_server_reader.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'roboflow_slip_reader.dart';
import 'slip_config.dart';
import 'slip_field_reader.dart';
import 'slip_models.dart';
import 'slip_reader.dart';

/// อ่านสลิปผ่านเซิร์ฟเวอร์ของเราเอง (Hugging Face Space: RF-DETR ตีกรอบ + EasyOCR/ThaiTrOCR อ่าน)
///
/// ส่งรูปไป `POST {SLIP_API_URL}/read-slip` แล้วแปลงผลเป็น [SlipRead] ส่งเข้าตัวให้คะแนนเดิม ([SlipReader.evaluate])
/// Space ที่หลับอยู่จะตอบ 503 ระหว่างตื่น/โหลดโมเดล → รอแล้วลองใหม่เอง
class SlipServerReader implements SlipFieldReader {
  SlipServerReader({
    required this.scorer,
    http.Client? client,
    void Function(String message)? onLog,
  }) : _client = client ?? http.Client(),
       _log = onLog;

  final SlipReader scorer;
  final http.Client _client;
  final void Function(String message)? _log;

  @override
  final List<String> errors = <String>[];

  @override
  bool get isConfigured => SlipConfig.slipApiUrl.isNotEmpty;

  @override
  String get setupHint =>
      'ไม่ได้ตั้ง SLIP_API_URL (ต้องรันด้วย --dart-define-from-file=env.json แล้วหยุดและรันใหม่ทั้งหมด)';

  @override
  Future<ScoredRead?> read(Uint8List bytes) async {
    errors.clear();
    final uri = Uri.parse(
      '${SlipConfig.slipApiUrl.replaceAll(RegExp(r'/+$'), '')}/read-slip',
    );
    for (var attempt = 1; attempt <= SlipConfig.slipApiWakeAttempts; attempt++) {
      try {
        final request = http.MultipartRequest('POST', uri)
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: 'slip.jpg'),
          );
        if (SlipConfig.slipApiToken.isNotEmpty) {
          request.headers['Authorization'] =
              'Bearer ${SlipConfig.slipApiToken}';
        }
        final response = await http.Response.fromStream(
          await _client.send(request).timeout(SlipConfig.slipApiTimeout),
        );
        // 503 = กำลังตื่น/โหลดโมเดล (ทั้งจาก Space เองและจาก app.py ระหว่างโหลด) → รอแล้วลองใหม่
        if (response.statusCode == 503 &&
            attempt < SlipConfig.slipApiWakeAttempts) {
          _log?.call(
            'เซิร์ฟเวอร์อ่านสลิปกำลังตื่น รอ ${SlipConfig.slipApiWakeDelay.inSeconds} วินาที '
            '(ครั้งที่ $attempt/${SlipConfig.slipApiWakeAttempts})',
          );
          await Future<void>.delayed(SlipConfig.slipApiWakeDelay);
          continue;
        }
        if (response.statusCode != 200) {
          errors.add(
            'เซิร์ฟเวอร์อ่านสลิปตอบ ${response.statusCode}: '
            '${_shorten(utf8.decode(response.bodyBytes, allowMalformed: true))}',
          );
          return null;
        }
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        if (json is! Map<String, dynamic>) {
          errors.add('ผลจากเซิร์ฟเวอร์ไม่ใช่ JSON object');
          return null;
        }
        _log?.call(
          'เซิร์ฟเวอร์อ่านสลิป ${json['seconds']} วินาที: ยอด ${json['amount']} '
          '${json['from_name']} → ${json['to_name']}',
        );
        return scoreJson(json, scorer);
      } on TimeoutException {
        errors.add(
          'เซิร์ฟเวอร์อ่านสลิปไม่ตอบภายใน ${SlipConfig.slipApiTimeout.inSeconds} วินาที',
        );
        return null;
      } catch (error) {
        errors.add(_shorten(error.toString()));
        _log?.call('เรียกเซิร์ฟเวอร์อ่านสลิปไม่สำเร็จ: $error');
        return null;
      }
    }
    errors.add('เซิร์ฟเวอร์อ่านสลิปยังไม่พร้อม (ตื่นไม่ทัน) ลองใหม่อีกครั้ง');
    return null;
  }

  /// ผล JSON ของเซิร์ฟเวอร์ → คะแนนเดิมของแอป + ธงที่เซิร์ฟเวอร์ส่งมา
  /// (แยกออกมาให้ทดสอบได้โดยไม่ต้องเรียกเครือข่าย)
  static ScoredRead scoreJson(Map<String, dynamic> json, SlipReader scorer) {
    final scored = scorer.evaluate(
      <SlipRead>[readFromJson(json)],
      source: 'slip_server',
      singleReadPenalty: 0.1,
    );
    final issues = List<String>.of(scored.issues);
    final amountFlag = (json['amount_flag'] ?? '').toString();
    final retry = (json['retry'] ?? '').toString();
    if (amountFlag.isNotEmpty) issues.add('ยอดเงินอ่านได้ไม่แน่ใจ ($amountFlag)');
    if (retry.isNotEmpty) issues.add('กล่องช่อง $retry ความมั่นใจต่ำ');
    if (amountFlag.isEmpty && retry.isEmpty) return scored;
    // มีธง = ให้ผู้ใช้ตรวจเสมอ (ต่ำกว่าเกณฑ์ verified)
    return ScoredRead(
      read: scored.read,
      score: math.min(scored.score, SlipConfig.verifiedScore - 0.05),
      issues: issues,
      date: scored.date,
      source: scored.source,
    );
  }

  /// แปลงช่องของเซิร์ฟเวอร์เป็นข้อความต่อช่อง แล้วใช้ตัวแปลงเดียวกับ Roboflow
  static SlipRead readFromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final value = json[key];
      if (value == null) return null;
      final s = value.toString().trim();
      return s.isEmpty ? null : s;
    }

    final amount = json['amount'];
    return RoboflowSlipReader.buildRead(<String, String>{
      // ส่งเป็น "18.00" (parseMoney ต้องการทศนิยม 2 หลัก ไม่งั้น "18.0" จะกลายเป็น 180)
      if (amount is num) SlipFields.amount: amount.toStringAsFixed(2),
      if (text('date') != null) SlipFields.date: text('date')!,
      if (text('ref_no') != null) SlipFields.refNo: text('ref_no')!,
      if (text('from_name') != null) SlipFields.fromName: text('from_name')!,
      if (text('to_name') != null) SlipFields.toName: text('to_name')!,
      if (text('bank') != null) SlipFields.fromBank: text('bank')!,
      if (text('title') != null) SlipFields.title: text('title')!,
      if (text('memo') != null) SlipFields.memo: text('memo')!,
    });
  }

  static String _shorten(String s) {
    final flat = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length > 200 ? '${flat.substring(0, 200)}…' : flat;
  }
}
