// Directory: lib/service/slip/
// File: slip_categorizer.dart

import 'slip_models.dart';
import 'slip_text.dart';

/// ชุดหมวดหมู่ตามประเภทสมุดบัญชี AI ต้องเลือกในรายการนี้เท่านั้น (ไม่คิดชื่อหมวดเอง)
class CategoryProfile {
  const CategoryProfile({
    required this.label,
    required this.income,
    required this.expense,
    this.flexible = const <String>[],
    this.hint = '',
    this.unspecified = 'ไม่ระบุ',
    this.useLegacyRules = false,
  });

  final String label;
  final List<String> income;
  final List<String> expense;

  /// หมวดที่พอปรับลดได้ (ใช้ในคำแนะนำลดค่าใช้จ่าย)
  final List<String> flexible;
  final String hint;

  /// ชื่อหมวดเมื่อข้อมูลไม่พอ (ชุดเดิมของแอปใช้ 'ทั่วไป')
  final String unspecified;

  /// true = ใช้กฎ regex จับชื่อร้านเดิมของแอป (7-11, ปตท. ฯลฯ) ก่อนถาม AI
  final bool useLegacyRules;

  /// ชุดเดิมของแอป: ใช้ชื่อหมวดเท่าที่แอปเคยสร้าง/แสดงอยู่แล้ว เพื่อไม่กระทบข้อมูลและหน้าจอเดิม
  static const CategoryProfile legacy = CategoryProfile(
    label: 'ร้านค้า',
    income: <String>['ลูกค้า', 'ทั่วไป'],
    expense: <String>[
      'ค่าแรง',
      'วัตถุดิบ',
      'ค่าอาหาร',
      'ค่าเดินทาง',
      'สาธารณูปโภค',
      'อุปกรณ์/บรรจุภัณฑ์',
      'ค่าเช่า',
      'ทั่วไป',
    ],
    flexible: <String>['ค่าอาหาร'],
    hint: 'ดูบันทึกช่วยจำก่อนถ้ามี แล้วดูชื่อคู่ค้า เช่น ร้านกาแฟ ร้านอาหาร → ค่าอาหาร, ตลาด ห้างค้าส่ง → วัตถุดิบ, การไฟฟ้า ประปา → สาธารณูปโภค',
    unspecified: 'ทั่วไป',
    useLegacyRules: true,
  );

  static const CategoryProfile business = CategoryProfile(
    label: 'ร้านค้า',
    income: <String>['ลูกค้าซื้อสินค้า/บริการ', 'สปอนเซอร์', 'รายรับอื่นๆ'],
    expense: <String>[
      'ค่าแรง/เงินเดือน',
      'ค่าวัตถุดิบ',
      'ค่าน้ำ/ไฟ/แก๊ส',
      'ค่าขนส่ง',
      'อาหาร/เครื่องดื่ม',
      'ค่าบริการ/ชำระบิล',
      'ค่าใช้จ่ายอื่นๆ',
    ],
    flexible: <String>['อาหาร/เครื่องดื่ม', 'ค่าใช้จ่ายอื่นๆ'],
    hint: 'ดูบันทึกช่วยจำก่อนถ้ามี แล้วดูชื่อคู่ค้า เช่น ร้านกาแฟ ร้านอาหาร ขนม → อาหาร/เครื่องดื่ม, บริษัททำความสะอาด ค่าบริการ เติมเงินมือถือ → ค่าบริการ/ชำระบิล',
  );

  /// ตัวอย่างเริ่มต้นสำหรับวัด/มูลนิธิ ควรให้ผู้ดูแลบัญชีจริงปรับก่อนใช้งาน
  static const CategoryProfile temple = CategoryProfile(
    label: 'วัด/มูลนิธิ',
    income: <String>[
      'ค่าบริจาคโรงศพ',
      'ค่าสังฆทาน/ถวายปัจจัย',
      'ผ้าป่า/กฐิน',
      'ค่าบำรุงวัด/ก่อสร้าง',
      'รายรับอื่นๆ',
    ],
    expense: <String>[
      'ค่าน้ำ/ไฟ',
      'ค่าซ่อมแซมเสนาสนะ',
      'ค่าภัตตาหาร/อาหาร',
      'ค่าจ้าง/ค่าแรง',
      'ค่าจัดงาน/พิธี',
      'ค่าใช้จ่ายอื่นๆ',
    ],
    flexible: <String>['ค่าใช้จ่ายอื่นๆ'],
    hint: 'ให้ยึดบันทึกช่วยจำเป็นหลัก (เช่น คำว่า โรงศพ สังฆทาน ถวาย ผ้าป่า กฐิน ก่อสร้าง บำรุงวัด ซ่อม ภัตตาหาร พิธี) ผู้บริจาคที่เป็นชื่อบุคคลและไม่มีบันทึกช่วยจำ ห้ามเดา ให้ตอบ ไม่ระบุ (สลิปไม่บอกวัตถุประสงค์ ควรให้ผู้บริจาคเลือกตอนส่งสลิป)',
  );

  /// เลือกชุดหมวดจากเอกสารสมุดบัญชี `users/{uid}/booklets/{id}`:
  ///  - `categories: {income: [...], expense: [...], flexible: [...], label: '...'}` = กำหนดเอง
  ///  - `type: 'temple' | 'business'` = ชุดสำเร็จรูป
  ///  - ไม่มีทั้งสองอย่าง = ชุดเดิมของแอป (legacy)
  static CategoryProfile fromBookletData(Map<String, dynamic>? data) {
    if (data == null) return legacy;
    final custom = data['categories'];
    if (custom is Map) {
      final income = _strings(custom['income']);
      final expense = _strings(custom['expense']);
      if (income.isNotEmpty && expense.isNotEmpty) {
        return CategoryProfile(
          label: custom['label']?.toString() ?? 'กำหนดเอง',
          income: income,
          expense: expense,
          flexible: _strings(custom['flexible'])
              .where((name) => expense.contains(name))
              .toList(),
        );
      }
    }
    switch (data['type']) {
      case 'temple':
        return temple;
      case 'business':
        return business;
      default:
        return legacy;
    }
  }

  static List<String> _strings(Object? value) => value is Iterable
      ? value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList()
      : <String>[];
}

/// วิธีที่ได้หมวดนั้นมา: internal | hint | rule | memory | ai | none
class CategoryDecision {
  const CategoryDecision(this.category, this.note, this.how);

  final String category;
  final String note;
  final String how;
}

/// ถาม AI แล้วคืนข้อความคำตอบ (คืน null/โยน error ได้ ระบบจะใช้ "ไม่ระบุ")
typedef CategoryAsk = Future<String?> Function(String prompt);

class _Rule {
  _Rule(this.category, this.pattern);

  final String category;
  final RegExp pattern;
}

/// จัดหมวดตามลำดับ: โอนภายใน → หมวดที่ผู้ใช้เลือก → กฎเดิมของแอป (เฉพาะชุด legacy) → ความจำในรอบนี้ → AI
class SlipCategorizer {
  SlipCategorizer({required this.profile, this.ask});

  final CategoryProfile profile;
  final CategoryAsk? ask;
  final Map<String, String> _memory = <String, String>{};

  // \b กับคำอังกฤษสั้นๆ กันไปตรงกลางคำอื่น (เช่น "ais" ใน "raising")
  static final List<_Rule> _legacyRules = <_Rule>[
    _Rule(
      'วัตถุดิบ/สินค้า',
      RegExp(
        r'7[- ]?eleven|7-11|เซเว่น|โลตัส|\blotus|makro|แม็คโคร|big\s?c\b|บิ๊กซี|\btops\b|ท็อปส์',
      ),
    ),
    _Rule(
      'ค่าอาหาร',
      RegExp(
        r'grab|foodpanda|ร้านอาหาร|restaurant|cafe|café|กาแฟ|ชาบู|หมูกระทะ',
      ),
    ),
    _Rule(
      'ค่าเดินทาง',
      RegExp(r'ปตท|\bptt\b|shell|เชลล์|บางจาก|น้ำมัน|fuel|gas station'),
    ),
    _Rule(
      'สาธารณูปโภค',
      RegExp(
        r'การไฟฟ้า|ประปา|ค่าไฟ|ค่าน้ำ|\bais\b|\bdtac\b|\btrue\b|internet|อินเทอร์เน็ต',
      ),
    ),
    _Rule(
      'อุปกรณ์/บรรจุภัณฑ์',
      RegExp(r'shopee|lazada|ช้อปปี้|ลาซาด้า|บรรจุภัณฑ์|กล่องพัสดุ'),
    ),
    _Rule('ค่าเช่า', RegExp(r'ค่าเช่า|\brent\b')),
    _Rule('ค่าแรง', RegExp(r'เงินเดือน|ค่าแรง|\bsalary\b|\bwage')),
  ];

  String? _legacyCategory(String text) {
    final value = text.toLowerCase();
    for (final rule in _legacyRules) {
      if (rule.pattern.hasMatch(value)) return rule.category;
    }
    return null;
  }

  /// [type] = income | expense | internal_transfer, [hint] = หมวดที่ผู้ใช้เลือกไว้ก่อนอัปโหลด
  Future<CategoryDecision> categorize({
    required SlipRead read,
    required String type,
    String? hint,
  }) async {
    if (type == 'internal_transfer') {
      return const CategoryDecision(
        'โอนภายใน',
        'โอนระหว่างบัญชีตัวเอง',
        'internal',
      );
    }
    final isOut = type == 'expense';
    final categories = isOut ? profile.expense : profile.income;
    final party = (isOut ? read.toName : read.fromName) ?? '';
    final partyId = (isOut ? read.toAccount : read.fromAccount) ?? '';
    final note = party.isEmpty ? '' : '${isOut ? 'จ่ายให้' : 'รับจาก'} $party';

    if (hint != null && categories.contains(hint)) {
      return CategoryDecision(hint, 'ผู้ใช้เลือกหมวดตอนอัปโหลด', 'hint');
    }
    if (profile.useLegacyRules && isOut) {
      final matched = _legacyCategory('$party ${read.memo ?? ''}');
      if (matched != null) return CategoryDecision(matched, note, 'rule');
    }
    for (final key in <String>[party, partyId]) {
      if (key.isEmpty) continue;
      final remembered = _memory['$type|$key'];
      if (remembered != null) {
        return CategoryDecision(remembered, note, 'memory');
      }
    }

    final asker = ask;
    if (asker == null) {
      return CategoryDecision(profile.unspecified, note, 'none');
    }
    try {
      final answer = parseJsonObject(
        await asker(_prompt(isOut: isOut, party: party, read: read)) ?? '',
      );
      final category = answer['category']?.toString().trim();
      if (category == null || !categories.contains(category)) {
        return CategoryDecision(profile.unspecified, note, 'ai');
      }
      for (final key in <String>[party, partyId]) {
        if (key.isNotEmpty) _memory['$type|$key'] = category;
      }
      final aiNote = answer['note']?.toString().trim() ?? '';
      return CategoryDecision(category, aiNote.isEmpty ? note : aiNote, 'ai');
    } catch (_) {
      return CategoryDecision(profile.unspecified, note, 'none');
    }
  }

  String _prompt({
    required bool isOut,
    required String party,
    required SlipRead read,
  }) {
    final categories = isOut ? profile.expense : profile.income;
    final direction = isOut ? 'เงินออก (รายจ่าย)' : 'เงินเข้า (รายรับ)';
    final memo = read.memo == null || read.memo!.isEmpty ? '-' : read.memo!;
    return 'จัดหมวดหมู่รายการโอนเงินของ${profile.label}\n'
        'ทิศทาง: $direction\n'
        'เลือก category จากรายการนี้เท่านั้น: ${categories.join(', ')}\n'
        '${profile.hint}\n'
        'เลือก "${profile.unspecified}" เฉพาะเมื่อแยกประเภทไม่ได้จริงๆ เช่น ชื่อบุคคลที่ไม่มีบันทึกช่วยจำ หรือชื่อที่ไม่บอกอะไรเลย\n'
        'ชื่อเล่น ชื่อบุคคล หรือชื่อโครงการรับชำระเงิน (เช่น ถุงเงิน) ไม่ได้บอกประเภท ห้ามเดา ต้องมีคำที่บอกประเภทชัดเจนจึงจะเลือกหมวดได้\n'
        'note = สรุปรายการสั้นๆ ไม่เกิน 15 คำ ใช้เฉพาะข้อมูลที่ให้\n'
        'ตอบเป็น JSON เท่านั้น: {"category": "...", "note": "..."}\n'
        '\n'
        'คู่ค้า: $party\n'
        'ยอด: ${read.amount ?? 0} บาท\n'
        'บันทึกช่วยจำ: $memo';
  }
}
