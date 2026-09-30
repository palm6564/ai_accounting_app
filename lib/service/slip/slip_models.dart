// Directory: lib/service/slip/
// File: slip_models.dart

/// ผลที่ AI อ่านได้จากสลิป 1 ครั้ง (ยังไม่ผ่านการตรวจ)
class SlipRead {
  const SlipRead({
    required this.isSlip,
    this.amount,
    this.fee,
    this.dateText,
    this.timeText,
    this.fromName,
    this.fromAccount,
    this.fromBank,
    this.toName,
    this.toAccount,
    this.toBank,
    this.refNo,
    this.memo,
    this.typeGuess,
  });

  final bool isSlip;
  final double? amount;
  final double? fee;
  final String? dateText;
  final String? timeText;
  final String? fromName;
  final String? fromAccount;
  final String? fromBank;
  final String? toName;
  final String? toAccount;
  final String? toBank;
  final String? refNo;
  final String? memo;

  /// AI เดาว่าเป็น income / expense / internal_transfer (ใช้เมื่อเทียบกับบัญชีของผู้ใช้ไม่ได้เท่านั้น)
  final String? typeGuess;

  /// แปลง JSON จาก AI คืน null ถ้า JSON ว่าง
  static SlipRead? fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return null;
    return SlipRead(
      isSlip: json['is_slip'] != false,
      amount: _toDouble(json['amount']),
      fee: _toDouble(json['fee']),
      dateText: _text(json['date_text']),
      timeText: _text(json['time_text']),
      fromName: _text(json['from_name']),
      fromAccount: _text(json['from_account']),
      fromBank: _text(json['from_bank']),
      toName: _text(json['to_name']),
      toAccount: _text(json['to_account']),
      toBank: _text(json['to_bank']),
      refNo: _text(json['ref_no']),
      memo: _text(json['memo']),
      typeGuess: _validType(_text(json['type_guess'])),
    );
  }

  static const List<String> _types = <String>[
    'income',
    'expense',
    'internal_transfer',
  ];

  static String? _validType(String? value) =>
      value != null && _types.contains(value) ? value : null;
}

String? _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
}

double? _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '') ?? '');
}

/// ผลอ่านที่ผ่านการตรวจแล้ว พร้อมคะแนนความมั่นใจ (0-1) และรายการปัญหา
class ScoredRead {
  const ScoredRead({
    required this.read,
    required this.score,
    required this.issues,
    required this.date,
    required this.source,
  });

  final SlipRead read;
  final double score;
  final List<String> issues;
  final DateTime? date;

  /// gemini_vision (อ่าน 2 รุ่นเทียบกัน) | gemini_vision_single | openai_... | groq_...
  final String source;
}

/// รายการที่พร้อมบันทึกลง Firestore (ฟิลด์ตรงกับที่แอปใช้อยู่เดิม)
class SlipOutcome {
  const SlipOutcome({
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.note,
    required this.confidence,
    required this.status,
    required this.refNo,
    required this.refKey,
    required this.date,
    required this.source,
    this.issues = const <String>[],
    this.isFallback = false,
  });

  final String title;
  final double amount;

  /// income | expense | internal_transfer
  final String type;
  final String category;
  final String note;
  final double confidence;

  /// verified | pending_review
  final String status;
  final String refNo;

  /// เลขอ้างอิงแบบมาตรฐาน (I/l/1 และ O/0 รวมกัน) ใช้ตัดสลิปซ้ำ
  final String refKey;
  final DateTime? date;
  final String source;
  final List<String> issues;

  /// true = ผลจากตัวสำรองที่ไม่ใช่ AI (นับเป็น offlineCount)
  final bool isFallback;

  /// ฟิลด์ที่เขียนลง Firestore (date เป็น DateTime? ให้ผู้เรียกแปลงเป็น Timestamp)
  Map<String, dynamic> toFields() => <String, dynamic>{
    'title': title,
    'amount': amount,
    'type': type,
    'category': category,
    'note': note,
    'status': status,
    'confidence': confidence,
    'refNo': refNo,
    'refKey': refKey,
    'issues': issues.join('; '),
    'source': source,
  };
}
