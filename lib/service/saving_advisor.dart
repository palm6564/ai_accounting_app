// Directory: lib/service/
// File: savings_advisor.dart

/// สิ่งที่แนะนำให้ลด 1 หมวด (ตัวเลขทั้งหมดคำนวณด้วยโค้ด)
class SavingsItem {
  const SavingsItem({
    required this.category,
    required this.reason,
    required this.reasonTh,
    required this.current,
    required this.sharePct,
    required this.cutPerMonth,
    required this.cutInPeriod,
    this.averageBefore,
    this.abovePreviousPct,
    this.cutPct,
  });

  final String category;

  /// rising | flexible_large
  final String reason;
  final String reasonTh;

  /// ยอดหมวดนี้ในช่วงที่เลือก (บาท)
  final double current;
  final int sharePct;

  /// ควรลดประมาณเท่าไรต่อเดือน / ตลอดช่วงที่เลือก (บาท)
  final int cutPerMonth;
  final int cutInPeriod;

  /// ยอดหมวดนี้ในช่วงก่อนหน้า (เฉพาะเหตุผล rising)
  final double? averageBefore;
  final int? abovePreviousPct;

  /// สัดส่วนที่แนะนำให้ลด (เฉพาะเหตุผล flexible_large)
  final int? cutPct;
}

class SavingsPlan {
  const SavingsPlan({
    required this.items,
    required this.hasHistory,
    required this.months,
    required this.totalCutInPeriod,
    required this.totalCutPerMonth,
    required this.profitAfter,
  });

  final List<SavingsItem> items;

  /// false = ไม่มีข้อมูลช่วงก่อนหน้าให้เทียบ คำแนะนำเป็นเพียงเบื้องต้น
  final bool hasHistory;
  final int months;
  final int totalCutInPeriod;
  final int totalCutPerMonth;

  /// เงินสุทธิของช่วงที่เลือกหลังลดตามคำแนะนำ (รายรับ - รายจ่าย + ยอดที่ลด)
  final double profitAfter;
}

/// แนะนำว่า "ควรลดหมวดไหน เท่าไร" จากรายจ่ายจริง แทนการคูณยอดที่ผู้ใช้กรอกกับจำนวนเดือน
///
/// กติกา (ค่าเริ่มต้นที่ผู้พัฒนาตั้งเอง ยังไม่ได้ตรวจกับผู้ใช้จริง ปรับได้ที่ค่าคงที่ด้านล่าง):
///  1. rising: ช่วงนี้สูงกว่าช่วงก่อนหน้า 20% ขึ้นไป (และต่างกันเกิน 50 บาท) → แนะนำกลับไปเท่าช่วงก่อนหน้า
///  2. flexible_large: หมวดที่ปรับลดได้ และมีสัดส่วน 20% ขึ้นไปของรายจ่าย → แนะนำลด 10%
///  3. ไม่แนะนำลดหมวดที่เป็นค่าตอบแทนคน (ค่าแรง เงินเดือน ค่าจ้าง) และหมวดที่ยังไม่ระบุ
///
/// ช่วงปัจจุบันและช่วงก่อนหน้าต้องยาวเท่ากัน (เช่น 3 เดือนล่าสุด กับ 3 เดือนก่อนหน้านั้น)
/// ตัวอย่างการเรียกจากหน้า ROI (มี expensesByCategory และ previousExpensesByCategory อยู่แล้ว):
///
///   final plan = SavingsAdvisor.suggest(
///     currentByCategory: expensesByCategory,
///     previousByCategory: previousExpensesByCategory,
///     income: income,
///     months: _periodMonths,
///     flexible: const ['ค่าอาหาร'],
///   );
class SavingsAdvisor {
  const SavingsAdvisor._();

  static const List<String> protectedWords = <String>[
    'ค่าแรง',
    'เงินเดือน',
    'ค่าจ้าง',
  ];
  static const List<String> unspecifiedNames = <String>['ไม่ระบุ', 'ทั่วไป'];
  static const double riseRatio = 1.2;
  static const double minCut = 50.0;
  static const double bigShare = 0.20;
  static const double defaultCutPct = 0.10;
  static const int maxItems = 3;

  static SavingsPlan suggest({
    required Map<String, double> currentByCategory,
    Map<String, double>? previousByCategory,
    required double income,
    int months = 1,
    List<String> flexible = const <String>[],
    double cutPct = defaultCutPct,
  }) {
    final safeMonths = months < 1 ? 1 : months;
    final hasHistory =
        previousByCategory != null && previousByCategory.isNotEmpty;
    final expense = currentByCategory.values.fold<double>(0.0, (a, b) => a + b);
    if (expense <= 0) {
      return SavingsPlan(
        items: const <SavingsItem>[],
        hasHistory: hasHistory,
        months: safeMonths,
        totalCutInPeriod: 0,
        totalCutPerMonth: 0,
        profitAfter: income - expense,
      );
    }

    final candidates = <SavingsItem>[];
    currentByCategory.forEach((category, current) {
      if (unspecifiedNames.contains(category)) return;
      if (protectedWords.any(category.contains)) return;
      final share = current / expense;
      final sharePct = (share * 100).round();
      final previous = previousByCategory?[category];

      if (previous != null &&
          previous > 0 &&
          current > previous * riseRatio &&
          current - previous >= minCut) {
        final cut = current - previous;
        candidates.add(
          SavingsItem(
            category: category,
            reason: 'rising',
            reasonTh: 'สูงกว่าช่วงก่อนหน้า',
            current: current,
            sharePct: sharePct,
            cutInPeriod: cut.round(),
            cutPerMonth: (cut / safeMonths).round(),
            averageBefore: previous,
            abovePreviousPct: ((current / previous - 1) * 100).round(),
          ),
        );
      } else if (flexible.contains(category) && share >= bigShare) {
        final cut = current * cutPct;
        candidates.add(
          SavingsItem(
            category: category,
            reason: 'flexible_large',
            reasonTh: 'เป็นหมวดที่ปรับลดได้และมีสัดส่วนสูง',
            current: current,
            sharePct: sharePct,
            cutInPeriod: cut.round(),
            cutPerMonth: (cut / safeMonths).round(),
            cutPct: (cutPct * 100).round(),
          ),
        );
      }
    });

    final items = candidates.where((item) => item.cutInPeriod > 0).toList()
      ..sort((a, b) => b.cutInPeriod.compareTo(a.cutInPeriod));
    final top = items.take(maxItems).toList();
    final totalPeriod = top.fold<int>(0, (sum, item) => sum + item.cutInPeriod);
    return SavingsPlan(
      items: top,
      hasHistory: hasHistory,
      months: safeMonths,
      totalCutInPeriod: totalPeriod,
      totalCutPerMonth: (totalPeriod / safeMonths).round(),
      profitAfter: income - expense + totalPeriod,
    );
  }
}
