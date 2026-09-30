// Directory: lib/service/slip/
// File: slip_text.dart

import 'dart:convert';

const String _thaiDigits = '๐๑๒๓๔๕๖๗๘๙';

/// แปลงเลขไทย ๐-๙ เป็น 0-9
String normalizeThaiDigits(String text) => text.replaceAllMapped(
  RegExp(r'[๐-๙]'),
  (match) => _thaiDigits.indexOf(match[0]!).toString(),
);

/// ดึง JSON object ก้อนแรกออกจากคำตอบของ AI (รับมือกรณีมี ```json หรือข้อความแถม)
Map<String, dynamic> parseJsonObject(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) return <String, dynamic>{};
  try {
    final parsed = jsonDecode(raw.substring(start, end + 1));
    return parsed is Map<String, dynamic> ? parsed : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
}

/// รูปแบบมาตรฐานของเลขอ้างอิง ใช้เทียบสลิปซ้ำเท่านั้น (ค่าที่เก็บลง refNo ยังเป็นค่าที่อ่านได้)
/// ตัวอักษรที่หน้าตาคล้ายกัน (I l 1 และ O 0) OCR/AI อ่านสลับกันได้ระหว่างรอบ จึงรวมเป็นตัวเดียวกัน
String canonRef(String? ref) {
  if (ref == null) return '';
  final cleaned = ref.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();
  return cleaned.replaceAll('I', '1').replaceAll('L', '1').replaceAll('O', '0');
}

/// ตัดช่องว่างและทำเป็นตัวพิมพ์เล็ก ใช้เทียบชื่อ
String squash(String? text) =>
    (text ?? '').replaceAll(RegExp(r'\s+'), '').toLowerCase();

final RegExp _nameOk = RegExp(r"^[฀-๿A-Za-z0-9 .,()*&/'\-]*$");

/// ชื่อที่มีอักษรแปลกปลอม (เช่น โมเดลพ่นอักษรภาษาอื่นปนมา) ยอมรับไทย อังกฤษ ตัวเลข และเครื่องหมายที่พบในชื่อ
bool isOddName(String? name) =>
    name != null && name.isNotEmpty && !_nameOk.hasMatch(name);

const Map<String, int> _months = <String, int>{
  'ม.ค.': 1,
  'ก.พ.': 2,
  'มี.ค.': 3,
  'เม.ย.': 4,
  'พ.ค.': 5,
  'มิ.ย.': 6,
  'ก.ค.': 7,
  'ส.ค.': 8,
  'ก.ย.': 9,
  'ต.ค.': 10,
  'พ.ย.': 11,
  'ธ.ค.': 12,
  'มกราคม': 1,
  'กุมภาพันธ์': 2,
  'มีนาคม': 3,
  'เมษายน': 4,
  'พฤษภาคม': 5,
  'มิถุนายน': 6,
  'กรกฎาคม': 7,
  'สิงหาคม': 8,
  'กันยายน': 9,
  'ตุลาคม': 10,
  'พฤศจิกายน': 11,
  'ธันวาคม': 12,
};

int _fullYear(int year) {
  var y = year;
  if (y < 100) y += 2500; // ปีสองหลักบนสลิปไทยเป็น พ.ศ. (เช่น 69 → 2569)
  return y > 2400 ? y - 543 : y;
}

/// อ่านวันที่บนสลิป (พ.ศ./ค.ศ. เลขไทย/อารบิก) คืน null ถ้าอ่านไม่ได้หรือเป็นวันที่ที่ไม่มีจริง
/// ถ้ามี [timeText] (HH:MM) จะใส่เวลาให้ด้วย
DateTime? parseSlipDate(String? dateText, [String? timeText]) {
  if (dateText == null) return null;
  final text = normalizeThaiDigits(dateText).trim();
  int? day;
  int? month;
  int? year;

  final numeric = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})')
      .firstMatch(text);
  if (numeric != null) {
    day = int.parse(numeric.group(1)!);
    month = int.parse(numeric.group(2)!);
    year = int.parse(numeric.group(3)!);
  } else {
    final named = RegExp(r'(\d{1,2})\s*([ก-๙.]+)\s*(\d{2,4})').firstMatch(text);
    final monthNumber = named == null ? null : _months[named.group(2)];
    if (named != null && monthNumber != null) {
      day = int.parse(named.group(1)!);
      month = monthNumber;
      year = int.parse(named.group(3)!);
    }
  }
  if (day == null || month == null || year == null) return null;

  var hour = 0;
  var minute = 0;
  final time = RegExp(r'(\d{1,2}):(\d{2})')
      .firstMatch(normalizeThaiDigits(timeText ?? ''));
  if (time != null) {
    final h = int.parse(time.group(1)!);
    final m = int.parse(time.group(2)!);
    if (h <= 23 && m <= 59) {
      hour = h;
      minute = m;
    }
  }

  final y = _fullYear(year);
  final result = DateTime(y, month, day, hour, minute);
  if (result.year != y || result.month != month || result.day != day) {
    return null; // เช่น 31 ก.พ. ที่ DateTime ปัดไปเดือนถัดไปเอง
  }
  return result;
}
