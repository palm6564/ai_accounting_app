// Directory: lib/service/slip/
// File: offline_slip_parser.dart

import 'slip_models.dart';
import 'slip_text.dart';

/// ตัวสำรองสุดท้ายเมื่อ AI ทุกตัวใช้ไม่ได้: ดึงข้อมูลจากข้อความ OCR ในเครื่องด้วย regex (ตรรกะเดิมของแอป)
/// ML Kit แบบ latin อ่านภาษาไทยไม่ได้ จึงพึ่งได้จริงแค่ยอดเงิน ความมั่นใจต่ำเสมอ จึงเข้าสถานะรอตรวจ
class OfflineSlipParser {
  const OfflineSlipParser._();

  static SlipOutcome parse(String rawText, {String? reason}) {
    final amount = _extractAmount(rawText);
    final sender = _labeledLine(
      rawText,
      r'(?:จาก|โอนจาก|ผู้โอน|ผู้ส่งเงิน|\bfrom\b)',
    );
    final recipient = _labeledLine(
      rawText,
      r'(?:ไปยัง|ผู้รับโอน|ผู้รับเงิน|ถึง|\bto\b)',
    );
    final reference =
        _labeledLine(
          rawText,
          r'(?:เลขที่รายการ|เลขอ้างอิง|รหัสอ้างอิง|รหัสรายการ|\breference\b|\bref(?:erence)?\s*(?:no\.?)?|\btransaction\s*id)',
        ) ??
        '';
    final title = recipient != null
        ? 'โอนให้ $recipient'
        : sender != null
        ? 'รับเงินจาก $sender'
        : 'สลิป OCR (รอตรวจ)';
    final snippet = rawText.length > 600 ? rawText.substring(0, 600) : rawText;

    return SlipOutcome(
      title: title,
      amount: amount,
      type: recipient != null || sender == null ? 'expense' : 'income',
      category: 'ทั่วไป',
      note:
          'บันทึกจาก ML Kit offline กรุณาตรวจสอบ${reason == null ? '' : '\nสาเหตุที่ AI ใช้ไม่ได้: $reason'}\n$snippet',
      confidence: amount > 0 ? 0.45 : 0.15,
      status: 'pending_review',
      refNo: reference,
      refKey: canonRef(reference),
      date: null,
      source: 'mlkit_offline',
      issues: <String>['อ่านด้วย regex ออฟไลน์', ?reason],
      isFallback: true,
    );
  }

  /// สลิปที่อ่านไม่ได้เลย สร้างรายการเปล่าให้ผู้ใช้กรอกเอง (ไม่ทิ้งสลิป)
  static SlipOutcome emergency({String? reason}) => SlipOutcome(
    title: 'สลิปอ่านไม่สำเร็จ (รอตรวจ)',
    amount: 0.0,
    type: 'expense',
    category: 'ทั่วไป',
    note:
        'ไม่สามารถอ่านสลิปด้วย AI ได้ โปรดแก้ไขข้อมูลด้วยตนเอง${reason == null ? '' : '\nสาเหตุ: $reason'}',
    confidence: 0.0,
    status: 'pending_review',
    refNo: '',
    refKey: '',
    date: null,
    source: 'manual_required',
    issues: <String>['อ่านสลิปไม่ได้', ?reason],
    isFallback: true,
  );

  static final List<RegExp> _amountPatterns = <RegExp>[
    RegExp(
      r'(?:จำนวนเงิน(?:ที่โอน)?|ยอด(?:เงิน|โอน|รวม)|เงินโอน|transfer\s*amount|transaction\s*amount|amount|total)\s*[:：]?\s*(?:฿|THB|บาท)?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:฿|THB)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ),
    RegExp(
      r'([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(?:บาท|THB|baht)',
      caseSensitive: false,
    ),
    RegExp(r'([0-9][0-9,]*\.[0-9]{2})'),
  ];

  static double _extractAmount(String rawText) {
    final text = normalizeThaiDigits(rawText);
    for (final pattern in _amountPatterns) {
      for (final match in pattern.allMatches(text)) {
        final amount = double.tryParse(
          match.group(1)?.replaceAll(',', '') ?? '',
        );
        if (amount != null && amount > 0) return amount;
      }
    }
    return 0;
  }

  /// หาบรรทัดที่ขึ้นต้นด้วยป้าย เช่น "จาก ..." ถ้าค่าอยู่บรรทัดถัดไปก็ใช้บรรทัดถัดไป
  static String? _labeledLine(String text, String labelPattern) {
    final lines = text.split(RegExp(r'\r?\n'));
    final label = RegExp(
      '^(?:$labelPattern)\\s*[:：#-]?\\s*(.*)\$',
      caseSensitive: false,
    );
    for (var index = 0; index < lines.length; index++) {
      final match = label.firstMatch(lines[index].trim());
      if (match == null) continue;
      final value = match.group(1)?.trim() ?? '';
      if (value.isNotEmpty) return value;
      if (index + 1 < lines.length) {
        final nextLine = lines[index + 1].trim();
        if (nextLine.isNotEmpty) return nextLine;
      }
    }
    return null;
  }
}
