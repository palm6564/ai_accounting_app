// Directory: lib/view/
// File: category_summary_view.dart

import 'package:flutter/material.dart';

import '../control/account_controller.dart';
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
  final TextEditingController _savingTargetController = TextEditingController();
  String _categoryType = 'expense';
  int _periodMonths = 3;
  int _planningMonths = 6;

  @override
  void dispose() {
    _savingTargetController.dispose();
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
    final savingTarget = double.tryParse(_savingTargetController.text) ?? 0;
    final periodExpenseMonthly = expense / _periodMonths;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'ช่วงเวลาสรุป',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DropdownButton<int>(
              value: _periodMonths,
              items: const [1, 3, 6, 12]
                  .map(
                    (months) => DropdownMenuItem(
                      value: months,
                      child: Text('$months เดือน'),
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
                const Text(
                  'ผลประกอบการในช่วงที่เลือก',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _summaryAmount('รายรับ', income, Colors.green.shade700),
                    _summaryAmount('รายจ่าย', expense, Colors.deepOrange),
                    _summaryAmount(
                      'คงเหลือ',
                      net,
                      net >= 0 ? Colors.indigo : Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'เฉลี่ยรายจ่าย ฿${periodExpenseMonthly.toStringAsFixed(2)} ต่อเดือน',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'expense',
              label: Text('รายจ่าย'),
              icon: Icon(Icons.trending_down),
            ),
            ButtonSegment(
              value: 'income',
              label: Text('รายรับ'),
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
              ? 'จำแนกต้นทุนและค่าใช้จ่าย'
              : 'จำแนกแหล่งรายรับ',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('ยังไม่มีรายการที่ยืนยันในช่วงเวลานี้'),
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
                  title: Text(entry.key),
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
                          '${(percent * 100).toStringAsFixed(1)}% ของยอดรวม',
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
        const Text(
          'แนวทางจัดการธุรกิจ',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildAdviceCard(net, income, expense, largestExpense),
        const SizedBox(height: 16),
        const Text(
          'จำลองแผนลดค่าใช้จ่าย',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _savingTargetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'ระบุจำนวนเงินที่ตั้งใจลดต่อเดือน',
                    prefixText: '฿ ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _planningMonths,
                  decoration: const InputDecoration(
                    labelText: 'ระยะเวลาที่ต้องการวางแผน',
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
                    if (value != null) setState(() => _planningMonths = value);
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'เงินที่ตั้งเป้าเก็บได้: '
                  '฿${(savingTarget * _planningMonths).toStringAsFixed(2)} '
                  'ใน $_planningMonths เดือน',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (savingTarget > periodExpenseMonthly && expense > 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'เป้าหมายสูงกว่ารายจ่ายเฉลี่ยต่อเดือน ลองปรับเป้าให้สอดคล้องกับรายการจริง',
                      style: TextStyle(color: Colors.deepOrange),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

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
    double net,
    double income,
    double expense,
    MapEntry<String, double>? topExpense,
  ) {
    final advice = <String>[];
    if (income == 0 && expense == 0) {
      advice.add('ยืนยันหรือเพิ่มรายการรับจ่ายเพื่อเริ่มสร้างแผนธุรกิจ');
    } else if (net < 0) {
      advice.add(
        'เงินออกสูงกว่าเงินเข้า ฿${(-net).toStringAsFixed(2)} ในช่วงนี้ '
        'พักการซื้อที่ไม่เร่งด่วนและตรวจรายการจ่ายก้อนใหญ่',
      );
    } else {
      advice.add(
        'เงินคงเหลือเป็นบวก ฿${net.toStringAsFixed(2)} ในช่วงที่เลือก',
      );
    }
    if (topExpense != null) {
      final share = expense > 0 ? topExpense.value / expense * 100 : 0.0;
      advice.add(
        'หมวด ${topExpense.key} ใช้เงิน ${share.toStringAsFixed(1)}% ของรายจ่าย '
        '(฿${topExpense.value.toStringAsFixed(2)}); ตรวจราคาซัพพลายเออร์และปริมาณซื้อ',
      );
    }
    if (income > 0 && expense / income > 0.8) {
      advice.add(
        'รายจ่ายคิดเป็น ${(expense / income * 100).toStringAsFixed(1)}% ของรายรับ '
        'ควรสำรองเงินสำหรับค่าใช้จ่ายจำเป็นก่อนนำเงินไปขยายกิจการ',
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
