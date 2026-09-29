// Directory: lib/view/
// File: category_summary_view.dart

import 'package:flutter/material.dart';

import '../control/account_controller.dart';
import '../l10n/app_text.dart';
import '../model/transaction.dart';

class CategorySummaryView extends StatefulWidget {
  final AccountController controller;
  final String type;

  const CategorySummaryView({
    super.key,
    required this.controller,
    this.type = 'all',
  });

  @override
  State<CategorySummaryView> createState() => _CategorySummaryViewState();
}

class _CategorySummaryViewState extends State<CategorySummaryView> {
  final TextEditingController _unitPriceController = TextEditingController();
  final TextEditingController _variableCostController = TextEditingController();
  final TextEditingController _monthlyFixedCostController =
      TextEditingController();
  final TextEditingController _monthlyUnitsController = TextEditingController();
  final TextEditingController _cashBalanceController = TextEditingController();
  String _categoryType = 'expense';
  int _periodMonths = 3;
  String _scenario = 'base';

  @override
  void dispose() {
    _unitPriceController.dispose();
    _variableCostController.dispose();
    _monthlyFixedCostController.dispose();
    _monthlyUnitsController.dispose();
    _cashBalanceController.dispose();
    super.dispose();
  }

  DateTime get _periodStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month - _periodMonths + 1);
  }

  List<TransactionModel> get _verifiedPeriodTransactions =>
      widget.controller.transactions.where((transaction) {
        return transaction.status == 'verified' &&
            !transaction.date.isBefore(_periodStart) &&
            (transaction.type == 'income' || transaction.type == 'expense');
      }).toList();

  double _totalFor(String type) => _verifiedPeriodTransactions
      .where((transaction) => transaction.type == type)
      .fold(0.0, (total, transaction) => total + transaction.amount);

  List<MapEntry<String, double>> get _categoryEntries {
    final totals = <String, double>{};
    for (final item in _verifiedPeriodTransactions.where(
      (transaction) => transaction.type == _categoryType,
    )) {
      totals.update(
        item.category,
        (amount) => amount + item.amount,
        ifAbsent: () => item.amount,
      );
    }
    return totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  @override
  Widget build(BuildContext context) {
    final entries = _categoryEntries;
    final income = _totalFor('income');
    final expense = _totalFor('expense');
    final net = income - expense;
    final largestExpense = entries.isNotEmpty && _categoryType == 'expense'
        ? entries.first
        : _expenseEntries().firstOrNull;
    final periodExpenseMonthly = expense / _periodMonths;
    final unitPrice = _readAmount(_unitPriceController);
    final variableCost = _readAmount(_variableCostController);
    final fixedCost = _readAmount(_monthlyFixedCostController);
    final plannedUnits = _readAmount(_monthlyUnitsController);
    final cashBalance = _readAmount(_cashBalanceController);
    final scenarioSalesFactor = _scenario == 'sales_down' ? 0.8 : 1.0;
    final scenarioCostFactor = _scenario == 'cost_up' ? 1.15 : 1.0;
    final contributionPerUnit = unitPrice - variableCost * scenarioCostFactor;
    final scenarioUnits = plannedUnits * scenarioSalesFactor;
    final projectedProfit = contributionPerUnit * scenarioUnits - fixedCost;
    final breakEvenUnits = contributionPerUnit > 0
        ? (fixedCost / contributionPerUnit).ceil()
        : null;
    final displayedBreakEvenUnits = breakEvenUnits ?? 0;
    final runwayDays = fixedCost > 0 && cashBalance > 0
        ? cashBalance / fixedCost * 30
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppText.tr(context, 'ช่วงเวลาสรุป'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DropdownButton<int>(
              value: _periodMonths,
              items: [1, 3, 6, 12]
                  .map(
                    (months) => DropdownMenuItem(
                      value: months,
                      child: Text(
                        AppText.tr(
                          context,
                          '$months เดือน',
                          english: '$months months',
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _periodMonths = value);
              },
            ),
          ],
        ),
        Card(
          color: net >= 0 ? Colors.green.shade50 : Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppText.tr(context, 'ผลประกอบการในช่วงที่เลือก'),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _summaryAmount(
                      AppText.tr(context, 'รายรับ'),
                      income,
                      Colors.green.shade700,
                    ),
                    _summaryAmount(
                      AppText.tr(context, 'รายจ่าย'),
                      expense,
                      Colors.deepOrange,
                    ),
                    _summaryAmount(
                      AppText.tr(context, 'คงเหลือ'),
                      net,
                      net >= 0 ? Colors.indigo : Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  AppText.tr(
                    context,
                    'เฉลี่ยรายจ่าย ฿${periodExpenseMonthly.toStringAsFixed(2)} ต่อเดือน',
                    english:
                        'Average expenses: ฿${periodExpenseMonthly.toStringAsFixed(2)} per month',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'expense',
              label: Text(AppText.tr(context, 'รายจ่าย')),
              icon: Icon(Icons.trending_down),
            ),
            ButtonSegment(
              value: 'income',
              label: Text(AppText.tr(context, 'รายรับ')),
              icon: Icon(Icons.trending_up),
            ),
          ],
          selected: {_categoryType},
          onSelectionChanged: (selection) =>
              setState(() => _categoryType = selection.first),
        ),
        const SizedBox(height: 16),
        Text(
          _categoryType == 'expense'
              ? AppText.tr(context, 'จำแนกต้นทุนและค่าใช้จ่าย')
              : AppText.tr(context, 'จำแนกแหล่งรายรับ'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppText.tr(context, 'ยังไม่มีรายการที่ยืนยันในช่วงเวลานี้'),
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: entries.map((entry) {
                final categoryTotal = _categoryType == 'expense'
                    ? expense
                    : income;
                final percent = categoryTotal > 0
                    ? entry.value / categoryTotal
                    : 0.0;
                return ListTile(
                  title: Text(AppText.categoryLabel(context, entry.key)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: percent,
                          color: _categoryType == 'expense'
                              ? Colors.deepOrange
                              : Colors.green,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppText.tr(
                            context,
                            '${(percent * 100).toStringAsFixed(1)}% ของยอดรวม',
                            english:
                                '${(percent * 100).toStringAsFixed(1)}% of total',
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Text('฿${entry.value.toStringAsFixed(2)}'),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          AppText.tr(context, 'แนวทางจัดการธุรกิจ'),
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildAdviceCard(context, net, income, expense, largestExpense),
        const SizedBox(height: 16),
        Text(
          AppText.tr(context, 'ทดลองแผนธุรกิจ'),
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppText.tr(
                    context,
                    'ลองปรับตัวเลขเพื่อดูจุดคุ้มทุนและกำไรโดยประมาณ',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _scenario,
                  decoration: InputDecoration(
                    labelText: AppText.tr(context, 'สถานการณ์จำลอง'),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'base',
                      child: Text(AppText.tr(context, 'ตามแผน')),
                    ),
                    DropdownMenuItem(
                      value: 'sales_down',
                      child: Text(AppText.tr(context, 'ยอดขายลดลง 20%')),
                    ),
                    DropdownMenuItem(
                      value: 'cost_up',
                      child: Text(
                        AppText.tr(context, 'ต้นทุนต่อชิ้นเพิ่ม 15%'),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _scenario = value);
                  },
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final fieldWidth = constraints.maxWidth >= 600
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _simulatorInput(
                          controller: _unitPriceController,
                          label: AppText.tr(context, 'ราคาขายต่อชิ้น'),
                          width: fieldWidth,
                        ),
                        _simulatorInput(
                          controller: _variableCostController,
                          label: AppText.tr(context, 'ต้นทุนต่อชิ้น'),
                          width: fieldWidth,
                        ),
                        _simulatorInput(
                          controller: _monthlyFixedCostController,
                          label: AppText.tr(context, 'ค่าใช้จ่ายประจำต่อเดือน'),
                          width: fieldWidth,
                        ),
                        _simulatorInput(
                          controller: _monthlyUnitsController,
                          label: AppText.tr(
                            context,
                            'จำนวนขายที่คาดต่อเดือน (ชิ้น)',
                          ),
                          width: fieldWidth,
                          currency: false,
                        ),
                        _simulatorInput(
                          controller: _cashBalanceController,
                          label: AppText.tr(context, 'เงินสดที่มี (ไม่บังคับ)'),
                          width: fieldWidth,
                        ),
                      ],
                    );
                  },
                ),
                if (unitPrice > 0 && fixedCost > 0 && plannedUnits > 0) ...[
                  const Divider(height: 24),
                  Text(
                    contributionPerUnit > 0
                        ? AppText.tr(
                            context,
                            'จุดคุ้มทุนประมาณ $displayedBreakEvenUnits ชิ้น/เดือน (ยอดขาย ฿${(displayedBreakEvenUnits * unitPrice).toStringAsFixed(0)})',
                            english:
                                'Break-even: $displayedBreakEvenUnits units/month (sales ฿${(displayedBreakEvenUnits * unitPrice).toStringAsFixed(0)})',
                          )
                        : AppText.tr(
                            context,
                            'ต้นทุนต่อชิ้นสูงกว่าราคาขาย ยังหาจุดคุ้มทุนไม่ได้',
                          ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppText.tr(
                      context,
                      'กำไรสุทธิตามสถานการณ์นี้: ฿${projectedProfit.toStringAsFixed(2)} / เดือน',
                      english:
                          'Estimated net profit: ฿${projectedProfit.toStringAsFixed(2)} / month',
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: projectedProfit >= 0
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                  if (runwayDays != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      AppText.tr(
                        context,
                        'เงินสดที่กรอกไว้อาจรองรับค่าใช้จ่ายประจำได้ประมาณ ${runwayDays.toStringAsFixed(0)} วัน (ยังไม่รวมรายรับใหม่)',
                        english:
                            'Entered cash may cover fixed costs for about ${runwayDays.toStringAsFixed(0)} days, excluding future income.',
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                Text(
                  AppText.tr(
                    context,
                    'ผลจำลองเป็นค่าประมาณจากตัวเลขที่กรอก ไม่ใช่ยอดบัญชีจริง',
                  ),
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  double _readAmount(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '')) ?? 0;

  Widget _simulatorInput({
    required TextEditingController controller,
    required String label,
    required double width,
    bool currency = true,
  }) => SizedBox(
    width: width,
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText: currency ? '฿ ' : null,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {}),
    ),
  );

  List<MapEntry<String, double>> _expenseEntries() {
    final totals = <String, double>{};
    for (final item in _verifiedPeriodTransactions.where(
      (transaction) => transaction.type == 'expense',
    )) {
      totals.update(
        item.category,
        (amount) => amount + item.amount,
        ifAbsent: () => item.amount,
      );
    }
    return totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  Widget _summaryAmount(String title, double value, Color color) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            '฿${value.toStringAsFixed(0)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );

  Widget _buildAdviceCard(
    BuildContext context,
    double net,
    double income,
    double expense,
    MapEntry<String, double>? topExpense,
  ) {
    final advice = <String>[];
    if (income == 0 && expense == 0) {
      advice.add(
        AppText.tr(
          context,
          'ยืนยันหรือเพิ่มรายการรับจ่ายเพื่อเริ่มสร้างแผนธุรกิจ',
          english: 'Confirm or add transactions to start building your business plan.',
        ),
      );
    } else if (net < 0) {
      advice.add(
        AppText.tr(
          context,
          'เงินออกสูงกว่าเงินเข้า ฿${(-net).toStringAsFixed(2)} ในช่วงนี้ พักการซื้อที่ไม่เร่งด่วนและตรวจรายการจ่ายก้อนใหญ่',
          english:
              'Outflow exceeds inflow by ฿${(-net).toStringAsFixed(2)}. Pause nonessential purchases and review large expenses.',
        ),
      );
    } else {
      advice.add(
        AppText.tr(
          context,
          'เงินคงเหลือเป็นบวก ฿${net.toStringAsFixed(2)} ในช่วงที่เลือก',
          english:
              'Net cash flow is positive at ฿${net.toStringAsFixed(2)} for this period.',
        ),
      );
    }
    if (topExpense != null) {
      final share = expense > 0 ? topExpense.value / expense * 100 : 0.0;
      advice.add(
        AppText.tr(
          context,
          'หมวด ${AppText.categoryLabel(context, topExpense.key)} ใช้เงิน ${share.toStringAsFixed(1)}% ของรายจ่าย (฿${topExpense.value.toStringAsFixed(2)}); ตรวจราคาซัพพลายเออร์และปริมาณซื้อ',
          english:
              '${AppText.categoryLabel(context, topExpense.key)} accounts for ${share.toStringAsFixed(1)}% of expenses (฿${topExpense.value.toStringAsFixed(2)}). Review supplier prices and order quantities.',
        ),
      );
    }
    if (income > 0 && expense / income > 0.8) {
      advice.add(
        AppText.tr(
          context,
          'รายจ่ายคิดเป็น ${(expense / income * 100).toStringAsFixed(1)}% ของรายรับ ควรสำรองเงินสำหรับค่าใช้จ่ายจำเป็นก่อนนำเงินไปขยายกิจการ',
          english:
              'Expenses are ${(expense / income * 100).toStringAsFixed(1)}% of income. Reserve essential costs before expanding.',
        ),
      );
    }
    return Card(
      color: Colors.blueGrey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: advice
              .map(
                (text) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(text)),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
