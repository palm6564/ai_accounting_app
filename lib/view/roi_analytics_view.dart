// Directory: lib/view/
// File: roi_analytics_view.dart

import 'package:flutter/material.dart';

import '../control/account_controller.dart';
import '../model/transaction.dart';

class RoiAnalyticsView extends StatefulWidget {
  final AccountController controller;

  const RoiAnalyticsView({super.key, required this.controller});

  @override
  State<RoiAnalyticsView> createState() => _RoiAnalyticsViewState();
}

class _RoiAnalyticsViewState extends State<RoiAnalyticsView> {
  final TextEditingController _monthlySavingController =
      TextEditingController();
  int _periodMonths = 3;
  int _planningMonths = 6;

  @override
  void dispose() {
    _monthlySavingController.dispose();
    super.dispose();
  }

  DateTime _monthStart(DateTime date, int offset) =>
      DateTime(date.year, date.month + offset);

  List<TransactionModel> _transactionsBetween(
    DateTime start,
    DateTime end,
    List<TransactionModel> transactions,
  ) => transactions
      .where(
        (transaction) =>
            transaction.status == 'verified' &&
            !transaction.date.isBefore(start) &&
            transaction.date.isBefore(end) &&
            (transaction.type == 'income' || transaction.type == 'expense'),
      )
      .toList();

  double _sum(List<TransactionModel> transactions, String type) => transactions
      .where((transaction) => transaction.type == type)
      .fold(0.0, (total, transaction) => total + transaction.amount);

  @override
  Widget build(BuildContext context) {
    final allTransactions = widget.controller.transactions;
    final now = DateTime.now();
    final currentStart = _monthStart(now, 1 - _periodMonths);
    final currentEnd = _monthStart(now, 1);
    final previousStart = _monthStart(now, 1 - (_periodMonths * 2));
    final current = _transactionsBetween(
      currentStart,
      currentEnd,
      allTransactions,
    );
    final previous = _transactionsBetween(
      previousStart,
      currentStart,
      allTransactions,
    );

    final income = _sum(current, 'income');
    final expense = _sum(current, 'expense');
    final previousIncome = _sum(previous, 'income');
    final previousExpense = _sum(previous, 'expense');
    final netCashFlow = income - expense;
    final expenseChange = previousExpense > 0
        ? ((expense - previousExpense) / previousExpense) * 100
        : null;
    final netMargin = income > 0 ? (netCashFlow / income) * 100 : 0.0;
    final savingPerMonth = double.tryParse(_monthlySavingController.text) ?? 0;

    final expensesByCategory = <String, double>{};
    final previousExpensesByCategory = <String, double>{};
    for (final transaction in current.where((item) => item.type == 'expense')) {
      expensesByCategory.update(
        transaction.category,
        (amount) => amount + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    for (final transaction in previous.where(
      (item) => item.type == 'expense',
    )) {
      previousExpensesByCategory.update(
        transaction.category,
        (amount) => amount + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    final rankedCategories = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategory = rankedCategories.isEmpty
        ? null
        : rankedCategories.first;
    final highestExpense = current
        .where((item) => item.type == 'expense')
        .fold<TransactionModel?>(
          null,
          (largest, item) =>
              largest == null || item.amount > largest.amount ? item : largest,
        );

    final monthlyData = List.generate(_periodMonths, (index) {
      final monthStart = _monthStart(now, index + 1 - _periodMonths);
      final nextMonth = _monthStart(monthStart, 1);
      final monthTransactions = _transactionsBetween(
        monthStart,
        nextMonth,
        allTransactions,
      );
      return _MonthSummary(
        month: monthStart,
        income: _sum(monthTransactions, 'income'),
        expense: _sum(monthTransactions, 'expense'),
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('วิเคราะห์การใช้เงิน'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ช่วงเวลาวิเคราะห์',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DropdownButton<int>(
                value: _periodMonths,
                items: const [1, 3, 6, 12]
                    .map(
                      (months) => DropdownMenuItem(
                        value: months,
                        child: Text('$months เดือนล่าสุด'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _periodMonths = value);
                },
              ),
            ],
          ),
          Text(
            '${_formatMonth(currentStart)} - ${_formatMonth(_monthStart(now, 0))}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metric('รายรับ', income, Colors.green.shade700),
              _metric('รายจ่าย', expense, Colors.deepOrange),
              _metric('เงินสุทธิ', netCashFlow, Colors.indigo),
              _metric('อัตรากำไรสุทธิ', netMargin, Colors.teal, suffix: '%'),
            ],
          ),
          const SizedBox(height: 20),
          _sectionTitle('กระแสเงินสดรายเดือน'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    child: _CashFlowChart(months: monthlyData),
                  ),
                  const SizedBox(height: 10),
                  const Wrap(
                    spacing: 16,
                    children: [
                      _Legend(color: Colors.green, label: 'รายรับ'),
                      _Legend(color: Colors.deepOrange, label: 'รายจ่าย'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('เปรียบเทียบช่วงก่อนหน้า'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    expenseChange == null || expenseChange <= 0
                        ? Icons.trending_down
                        : Icons.trending_up,
                    color: expenseChange == null || expenseChange <= 0
                        ? Colors.green
                        : Colors.deepOrange,
                  ),
                  title: const Text('รายจ่ายเทียบช่วงก่อนหน้า'),
                  subtitle: Text(
                    expenseChange == null
                        ? 'ยังไม่มีข้อมูลช่วงก่อนหน้าให้เปรียบเทียบ'
                        : '${expenseChange.abs().toStringAsFixed(1)}% ${expenseChange > 0 ? 'เพิ่มขึ้น' : 'ลดลง'}',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.compare_arrows,
                    color: Colors.indigo,
                  ),
                  title: const Text('เงินสุทธิช่วงนี้'),
                  subtitle: Text(
                    '฿${netCashFlow.toStringAsFixed(2)} เทียบกับ ฿${(previousIncome - previousExpense).toStringAsFixed(2)} ในช่วงก่อนหน้า',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('แจกแจงรายจ่ายตามหมวด'),
          if (rankedCategories.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('ยังไม่มีรายการรายจ่ายที่ยืนยันแล้วในช่วงนี้'),
              ),
            )
          else
            Card(
              child: Column(
                children: rankedCategories.map((entry) {
                  final share = expense > 0 ? entry.value / expense : 0.0;
                  final oldValue = previousExpensesByCategory[entry.key] ?? 0;
                  final change = oldValue > 0
                      ? ((entry.value - oldValue) / oldValue) * 100
                      : null;
                  return ListTile(
                    title: Text(entry.key),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: share),
                        const SizedBox(height: 4),
                        Text(
                          '${(share * 100).toStringAsFixed(1)}% ของรายจ่าย'
                          '${change == null ? '' : ' • ${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% เทียบช่วงก่อน'}',
                        ),
                      ],
                    ),
                    trailing: Text('฿${entry.value.toStringAsFixed(0)}'),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 16),
          _sectionTitle('คำแนะนำจากรายการจริง'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _recommendation(
                  income: income,
                  expense: expense,
                  netCashFlow: netCashFlow,
                  topCategory: topCategory,
                  highestExpense: highestExpense,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('ทดลองวางแผนจากจำนวนเงิน'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _monthlySavingController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'ตั้งเป้าลดรายจ่ายต่อเดือน (บาท)',
                      prefixText: '฿ ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _planningMonths,
                    decoration: const InputDecoration(
                      labelText: 'ระยะเวลาวางแผน',
                      border: OutlineInputBorder(),
                    ),
                    items: const [1, 3, 6, 12]
                        .map(
                          (months) => DropdownMenuItem(
                            value: months,
                            child: Text('$months เดือน'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _planningMonths = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'หากทำได้ตามเป้า จะเหลือเงินเพิ่มประมาณ '
                    '฿${(savingPerMonth * _planningMonths).toStringAsFixed(2)} '
                    'ใน $_planningMonths เดือน (ยังไม่รวมการเปลี่ยนแปลงรายรับ)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (topCategory != null && savingPerMonth > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'หมวดที่มีรายจ่ายสูงสุดคือ ${topCategory.key}; '
                      'เป้าลดรายจ่ายคิดเป็น '
                      '${topCategory.value > 0 ? (savingPerMonth / topCategory.value * 100).toStringAsFixed(1) : '0.0'}% '
                      'ของยอดหมวดนี้ในช่วงที่เลือก.',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _metric(
    String title,
    double value,
    Color color, {
    String suffix = '',
  }) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 40) / 2,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 4),
              Text(
                '${suffix == '%' ? value.toStringAsFixed(1) : '฿${value.toStringAsFixed(2)}'}$suffix',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
    ),
  );

  String _formatMonth(DateTime month) => '${month.month}/${month.year}';

  String _recommendation({
    required double income,
    required double expense,
    required double netCashFlow,
    required MapEntry<String, double>? topCategory,
    required TransactionModel? highestExpense,
  }) {
    if (income == 0 && expense == 0) {
      return 'ยังไม่มีรายการที่ยืนยันในช่วงนี้ เพิ่มหรือยืนยันรายการเพื่อเริ่มวิเคราะห์';
    }
    if (netCashFlow < 0) {
      return 'รายจ่ายสูงกว่ารายรับ ฿${(-netCashFlow).toStringAsFixed(2)} '
          'ในช่วงที่เลือก เริ่มตรวจหมวด ${topCategory?.key ?? 'รายจ่าย'} '
          'ซึ่งใช้เงิน ฿${(topCategory?.value ?? 0).toStringAsFixed(2)} ก่อน';
    }
    if (topCategory != null && expense > 0) {
      final share = topCategory.value / expense * 100;
      final largestMessage = highestExpense == null
          ? ''
          : ' รายการรายจ่ายสูงสุดคือ "${highestExpense.title}" '
                '฿${highestExpense.amount.toStringAsFixed(2)}.';
      return 'เงินสุทธิเป็นบวก ฿${netCashFlow.toStringAsFixed(2)}. '
          'หมวด ${topCategory.key} ใช้ ${share.toStringAsFixed(1)}% '
          'ของรายจ่ายทั้งหมด พิจารณาตรวจราคา/ปริมาณซื้อในหมวดนี้.$largestMessage';
    }
    return 'ยังไม่มีรายจ่ายในช่วงนี้ รักษาการบันทึกรายการให้ครบเพื่อเห็นต้นทุนจริง';
  }
}

class _MonthSummary {
  final DateTime month;
  final double income;
  final double expense;

  const _MonthSummary({
    required this.month,
    required this.income,
    required this.expense,
  });
}

class _CashFlowChart extends StatelessWidget {
  final List<_MonthSummary> months;

  const _CashFlowChart({required this.months});

  @override
  Widget build(BuildContext context) {
    final maximum = months.fold<double>(
      0,
      (value, month) =>
          [value, month.income, month.expense].reduce((a, b) => a > b ? a : b),
    );

    if (maximum <= 0) {
      return const Center(child: Text('ยังไม่มีข้อมูลในช่วงเวลานี้'));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: months.map((month) {
        final incomeHeight = (month.income / maximum * 128).clamp(2.0, 128.0);
        final expenseHeight = (month.expense / maximum * 128).clamp(2.0, 128.0);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _bar(incomeHeight, Colors.green),
                      const SizedBox(width: 3),
                      _bar(expenseHeight, Colors.deepOrange),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${month.month.month}/${month.month.year}',
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _bar(double height, Color color) => Container(
    width: 14,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
    ),
  );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, color: color),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
}
