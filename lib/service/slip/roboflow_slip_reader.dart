// Directory: lib/service/slip/
// File: roboflow_slip_reader.dart

import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'field_ocr.dart';
import 'roboflow_detector.dart';
import 'slip_field_reader.dart';
import 'slip_models.dart';
import 'slip_reader.dart';
import 'slip_text.dart';

/// ชื่อ class ใน Roboflow (ตามที่ label ไว้ใน dataset) → ช่องที่แอปใช้
class SlipFields {
  const SlipFields._();

  static const String amount = 'amount';
  static const String date = 'date';
  static const String refNo = 'ref_no';
  static const String fromName = 'from_name';
  static const String toName = 'to_name';
  static const String fromBank = 'from_bank';
  static const String title = 'title'; // หัวสลิป เช่น โอนเงินสำเร็จ / เติมเงินสำเร็จ
  static const String memo = 'memo'; // บันทึกช่วยจำที่ผู้โอนพิมพ์เอง

  /// class ที่ตั้งใน Roboflow: money / name (ผู้โอน) / sent (ผู้รับ) / bank / type payment / memo / silp
  /// ถ้าเทรนใหม่ด้วยชื่อ amount, from_name, to_name ฯลฯ ก็ใช้ได้เลย (ชื่อตรงกับช่องอยู่แล้ว)
  static const Map<String, String> alias = <String, String>{
    'money': amount,
    'name': fromName,
    'sent': toName,
    'bank': fromBank,
    'type payment': title,
    'type_payment': title,
  };

  /// ช่องที่มีอักษรไทย → ใช้ Tesseract ภาษาไทย
  static const Set<String> thai = <String>{
    date,
    fromName,
    toName,
    fromBank,
    title,
    memo,
  };

  /// ช่องที่กรอบครอบหลายบรรทัด (ป้าย + ชื่อ + เลขบัญชี / ป้าย + ข้อความ) → อ่านแบบหลายบรรทัด
  static const Set<String> multiline = <String>{fromName, toName, memo};

  /// ช่องที่อาจมีกล่องมากกว่า 1 (เช่น sent = โลโก้ + ชื่อ) ให้ลองทีละกล่องจนกว่าจะอ่านได้
  static const Set<String> names = <String>{fromName, toName};
}

/// อ่านสลิปแบบไม่ใช้ AI สำเร็จรูป: โมเดลที่เทรนเองบน Roboflow หาตำแหน่งแต่ละช่อง → ตัดภาพ → OCR ในเครื่อง
/// → แปลงเป็น [SlipRead] เดียวกับของเดิม แล้วส่งเข้าตัวให้คะแนนเดิม ([SlipReader.evaluate])
class RoboflowSlipReader implements SlipFieldReader {
  RoboflowSlipReader({
    required this.detector,
    required this.scorer,
    FieldOcr? ocr,
    void Function(String message)? onLog,
  }) : ocr = ocr ?? LocalFieldOcr(),
       _log = onLog;

  final RoboflowDetector detector;
  final SlipReader scorer;
  final FieldOcr ocr;
  final void Function(String message)? _log;

  /// สาเหตุที่อ่านไม่สำเร็จในครั้งล่าสุด
  @override
  final List<String> errors = <String>[];

  @override
  bool get isConfigured => detector.isConfigured;

  @override
  String get setupHint =>
      'ไม่ได้ตั้ง ROBOFLOW_API_KEY / ROBOFLOW_MODEL (ต้องรันด้วย --dart-define-from-file=env.json แล้วหยุดและรันใหม่ทั้งหมด)';

  @override
  Future<ScoredRead?> read(Uint8List bytes) async {
    errors.clear();
    try {
      final detection = await detector.detect(bytes);
      final grouped = <String, List<FieldBox>>{};
      for (final box in detection.boxes) {
        final label = box.label.trim().toLowerCase();
        final field = SlipFields.alias[label] ?? label;
        // silp = กรอบทั้งใบ ไม่มีข้อความให้อ่าน
        if (field == 'silp') continue;
        grouped.putIfAbsent(field, () => <FieldBox>[]).add(box);
      }
      if (grouped.isEmpty) {
        // ไม่เจอช่องใดเลย = น่าจะไม่ใช่สลิป
        return scorer.evaluate(
          <SlipRead>[const SlipRead(isSlip: false)],
          source: 'roboflow_local_ocr',
        );
      }

      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        errors.add('ถอดรหัสภาพไม่ได้');
        return null;
      }
      final image = img.bakeOrientation(decoded);
      final scale = detection.imageWidth > 0
          ? image.width / detection.imageWidth
          : 1.0;

      final text = <String, String>{};
      for (final entry in grouped.entries) {
        // กล่องชื่อ: ลองกล่องที่กว้างกว่าสูงมากที่สุดก่อน (ข้อความ) โลโก้เป็นสี่เหลี่ยมจัตุรัสจึงไว้ท้าย
        final candidates = entry.value.toList()
          ..sort((a, b) {
            if (!SlipFields.names.contains(entry.key)) {
              return b.confidence.compareTo(a.confidence);
            }
            return (b.width / b.height).compareTo(a.width / a.height);
          });
        for (final box in candidates.take(3)) {
          final crop = cropField(
            image,
            cx: box.cx,
            cy: box.cy,
            width: box.width,
            height: box.height,
            scale: scale,
          );
          if (crop == null) continue;
          final value = await ocr.read(
            crop,
            thai: SlipFields.thai.contains(entry.key),
            multiline: SlipFields.multiline.contains(entry.key),
          );
          _log?.call(
            '${entry.key} (${box.confidence.toStringAsFixed(2)}): $value',
          );
          if (value != null && value.trim().length >= 2) {
            text[entry.key] = value.trim();
            break;
          }
        }
      }

      // dataset ไม่มี class วันที่/รหัสอ้างอิง → อ่านทั้งใบหนึ่งครั้งแล้วจับด้วย regex
      if (!text.containsKey(SlipFields.date) ||
          !text.containsKey(SlipFields.refNo)) {
        final full = cropField(
          image,
          cx: image.width / 2,
          cy: image.height / 2,
          width: image.width.toDouble(),
          height: image.height.toDouble(),
          pad: 0,
        );
        final whole = full == null
            ? null
            : await ocr.read(full, thai: true, multiline: true);
        if (whole != null) {
          final date = extractDate(whole);
          final ref = extractRef(whole);
          if (date != null) text.putIfAbsent(SlipFields.date, () => date);
          if (ref != null) text.putIfAbsent(SlipFields.refNo, () => ref);
        }
      }
      return scorer.evaluate(
        <SlipRead>[buildRead(text)],
        source: 'roboflow_local_ocr',
        singleReadPenalty: 0.1,
      );
    } catch (error) {
      errors.add(error.toString().replaceAll(RegExp(r'\s+'), ' '));
      _log?.call('Roboflow อ่านสลิปไม่สำเร็จ: $error');
      return null;
    }
  }

  /// แปลงข้อความดิบของแต่ละช่องเป็น [SlipRead] (แยกออกมาให้ทดสอบได้โดยไม่ต้องมีภาพ)
  static SlipRead buildRead(Map<String, String> text) {
    final dateRaw = text[SlipFields.date];
    final timeRaw = dateRaw;
    final time = RegExp(
      r'(\d{1,2})[:.](\d{2})',
    ).firstMatch(normalizeThaiDigits(timeRaw ?? ''));
    return SlipRead(
      isSlip: true,
      amount: parseMoney(text[SlipFields.amount]),
      dateText: dateRaw == null ? null : normalizeThaiDigits(dateRaw),
      timeText: time == null ? null : '${time.group(1)}:${time.group(2)}',
      fromName: cleanName(text[SlipFields.fromName]),
      fromAccount: accountIn(text[SlipFields.fromName]),
      fromBank: cleanName(text[SlipFields.fromBank]),
      toName: cleanName(text[SlipFields.toName]),
      toAccount: accountIn(text[SlipFields.toName]),
      refNo: cleanRef(text[SlipFields.refNo]),
      memo: cleanMemo(text[SlipFields.memo]),
      typeGuess: typeFromTitle(text[SlipFields.title]),
    );
  }

  static final RegExp _labelOnly = RegExp(
    r'^(?:จาก|ไปยัง|ถึง|to|from)\s*[:：]?$',
    caseSensitive: false,
  );
  static final RegExp _labelPrefix = RegExp(
    r'^(?:จาก|ไปยัง|ถึง|to|from)\s*[:：]?\s+',
    caseSensitive: false,
  );
  static final RegExp _accountLine = RegExp(r'^[xX*\d\-\s]{5,}$');

  static List<String> _lines(String raw) => raw
      .split(RegExp(r'\r?\n'))
      .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .toList();

  /// กรอบชื่อบางสลิปครอบทั้งแถว (ป้าย "จาก" + ชื่อ + เลขบัญชี) → เอาบรรทัดชื่อบรรทัดแรก
  static String? cleanName(String? raw) {
    if (raw == null) return null;
    for (final line in _lines(raw)) {
      if (_labelOnly.hasMatch(line)) continue;
      final normalized = normalizeThaiDigits(line);
      if (_accountLine.hasMatch(normalized)) continue;
      final s = line
          .replaceAll(RegExp(r'\s*\(\s*\d+\s*\)\s*$'), '') // รหัสท้ายชื่อ (24376)
          .replaceAll(_labelPrefix, '')
          .trim();
      if (s.length >= 2) return s;
    }
    return null;
  }

  /// เลขบัญชีที่อยู่ในกรอบชื่อ เช่น "xxx-xxx905-1"
  static String? accountIn(String? raw) {
    if (raw == null) return null;
    for (final line in _lines(raw)) {
      if (_accountLine.hasMatch(normalizeThaiDigits(line))) {
        return cleanAccount(line);
      }
    }
    return null;
  }

  /// "บันทึกช่วยจำ ร่วมทำบุญ…" → ตัดป้ายออก เหลือข้อความที่ผู้โอนพิมพ์
  static String? cleanMemo(String? raw) {
    if (raw == null) return null;
    final lines = _lines(raw)
      ..removeWhere((line) => RegExp(r'^บันทึกช่วยจำ\s*[:：]?$').hasMatch(line));
    final s = lines
        .join(' ')
        .replaceAll(RegExp(r'^บันทึกช่วยจำ\s*[:：]?\s*'), '')
        .trim();
    return s.length < 2 ? null : s;
  }

  /// "1,250.00 บาท" → 1250.0 ; OCR มักอ่านจุดทศนิยมเป็นคอมมา/ช่องว่าง จึงรองรับ "1250,00" ด้วย
  static double? parseMoney(String? raw) {
    if (raw == null) return null;
    var s = normalizeThaiDigits(raw).replaceAll(RegExp(r'[^0-9.,]'), '');
    if (s.isEmpty) return null;
    final tail = RegExp(r'^(.*)[.,](\d{2})$').firstMatch(s);
    if (tail != null) {
      s = '${tail.group(1)!.replaceAll(RegExp(r'[.,]'), '')}.${tail.group(2)}';
    } else {
      s = s.replaceAll(RegExp(r'[.,]'), '');
    }
    return double.tryParse(s);
  }

  /// หัวสลิป → เดาประเภท (ใช้เมื่อเทียบกับบัญชีผู้ใช้ไม่ได้เท่านั้น)
  static String? typeFromTitle(String? title) {
    if (title == null) return null;
    if (title.contains('เติมเงิน') || title.contains('จ่ายบิล')) {
      return 'expense';
    }
    return null;
  }

  /// จับวันที่/เวลาจากข้อความทั้งใบ เช่น "17 ต.ค. 2569 - 18:59"
  static String? extractDate(String raw) {
    final text = normalizeThaiDigits(raw);
    final named = RegExp(
      r'(\d{1,2}\s*[ก-ฮ][ก-ฮ.]{1,10}\s*(?:25\d{2}|\d{2}))(?:\s*[-–]?\s*(\d{1,2}:\d{2}))?',
    ).firstMatch(text);
    if (named != null) {
      return [named.group(1), named.group(2)].whereType<String>().join(' ');
    }
    final numeric = RegExp(
      r'(\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4})(?:\s*(\d{1,2}:\d{2}))?',
    ).firstMatch(text);
    if (numeric == null) return null;
    return [numeric.group(1), numeric.group(2)].whereType<String>().join(' ');
  }

  /// จับรหัสอ้างอิง: ตามหลังคำว่า "อ้างอิง" ถ้าไม่เจอป้าย ใช้ token ยาว 12+ ที่มีทั้งตัวอักษรและตัวเลข
  /// (ไม่ใช้เลขล้วน เพราะจะไปชนเบอร์โทร/เลขบัญชี)
  static String? extractRef(String raw) {
    final labeled = RegExp(
      r'อ้างอิง\s*[:：]?\s*([A-Za-z0-9]{8,})',
    ).firstMatch(raw);
    if (labeled != null) return labeled.group(1);
    for (final token in raw.split(RegExp(r'\s+'))) {
      if (RegExp(r'^[A-Za-z0-9]{12,}$').hasMatch(token) &&
          RegExp(r'[A-Za-z]').hasMatch(token) &&
          RegExp(r'\d').hasMatch(token)) {
        return token;
      }
    }
    return null;
  }

  static String? cleanAccount(String? raw) {
    if (raw == null) return null;
    final s = normalizeThaiDigits(raw).replaceAll(RegExp(r'[^0-9xX*\-]'), '');
    return s.length < 3 ? null : s;
  }

  static String? cleanRef(String? raw) {
    if (raw == null) return null;
    final s = raw.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
    return s.length < 6 ? null : s;
  }
}
