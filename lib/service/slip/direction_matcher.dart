// Directory: lib/service/slip/
// File: direction_matcher.dart

import 'slip_models.dart';

/// ตัดสินว่าสลิปเป็นเงินเข้า / เงินออก / โอนระหว่างบัญชีตัวเอง ด้วยการเทียบชื่อและเลขบัญชีของผู้ใช้ (โค้ดล้วน ไม่ให้ AI เดา)
///
/// - [names] ชื่อผู้ใช้ เช่น displayName สลิปมักปิดชื่อ ("นาย จิรภัทร บ***") จึงเทียบส่วนหน้าที่เห็นครบ
/// - [accounts] เลขบัญชี/เบอร์ของผู้ใช้ สลิปมักปิดเลขกลาง จึงเทียบเฉพาะตัวเลขท้าย (อย่างน้อย 4 หลัก)
class OwnerMatcher {
  OwnerMatcher({
    Iterable<String> names = const <String>[],
    Iterable<String> accounts = const <String>[],
  }) : _names = names
           .map((name) => _splitName(name).base)
           .where((base) => base.length >= 3)
           .toList(),
       _accounts = accounts
           .map(_digits)
           .where((digits) => digits.length >= 4)
           .toList();

  final List<String> _names;
  final List<String> _accounts;

  /// มีข้อมูลให้เทียบหรือไม่
  bool get isConfigured => _names.isNotEmpty || _accounts.isNotEmpty;

  /// ชื่อหรือเลขบัญชีบนสลิปเป็นของผู้ใช้หรือไม่
  bool matches(String? name, String? account) =>
      (name != null && _nameMatches(name)) ||
      (account != null && _accountMatches(account));

  /// income | expense | internal_transfer หรือ null ถ้าไม่เจอบัญชีของผู้ใช้เลย
  String? detectType(SlipRead read) {
    final fromMine = matches(read.fromName, read.fromAccount);
    final toMine = matches(read.toName, read.toAccount);
    if (fromMine && toMine) return 'internal_transfer';
    if (fromMine) return 'expense';
    if (toMine) return 'income';
    return null;
  }

  bool _nameMatches(String slipName) {
    final slip = _splitName(slipName);
    if (slip.base.length < 3) return false;
    for (final owner in _names) {
      if (slip.masked) {
        // ชื่อถูกปิดท้ายด้วย * เทียบว่าชื่อผู้ใช้ขึ้นต้นด้วยส่วนที่เห็น (ต้องยาวพอกันเทียบผิดคน)
        if (slip.base.length >= 5 && owner.startsWith(slip.base)) return true;
      } else if (owner == slip.base) {
        return true;
      } else if (slip.base.length >= 6 &&
          owner.length >= 6 &&
          (owner.contains(slip.base) || slip.base.contains(owner))) {
        return true;
      }
    }
    return false;
  }

  bool _accountMatches(String slipAccount) {
    final digits = _digits(slipAccount);
    if (digits.length < 4) return false;
    return _accounts.any(
      (mine) => digits.endsWith(mine) || mine.endsWith(digits),
    );
  }

  static String _digits(String text) => text.replaceAll(RegExp(r'[^0-9]'), '');

  static final RegExp _title = RegExp(
    r'^(นางสาว|นาง|นาย|น\.ส\.|ด\.ช\.|ด\.ญ\.|mrs\.?|mr\.?|miss|ms\.?)',
    caseSensitive: false,
  );

  /// ตัดช่องว่าง/คำนำหน้า/จุด แล้วแยกส่วนที่เห็นครบ (base) กับธงว่าถูกปิดด้วย * หรือไม่
  static _Name _splitName(String raw) {
    var text = raw.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    text = text.replaceFirst(_title, '');
    final star = text.indexOf('*');
    final masked = star >= 0;
    final visible = masked ? text.substring(0, star) : text;
    return _Name(visible.replaceAll('.', ''), masked);
  }
}

class _Name {
  const _Name(this.base, this.masked);

  final String base;
  final bool masked;
}
