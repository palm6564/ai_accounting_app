// Directory: lib/view/
// File: roi_analytics_view.dart

import 'package:flutter/material.dart';

import '../control/app_preferences.dart';
import '../control/account_controller.dart';
import '../l10n/app_text.dart';
import '../model/transaction.dart';

class RoiAnalyticsView extends StatefulWidget {
  final AccountController controller;
  final AppPreferences? preferences;

  const RoiAnalyticsView({
    super.key,
    required this.controller,
    this.preferences,
  });

  @override
  State<RoiAnalyticsView> createState() => _RoiAnalyticsViewState();
}

class _RoiAnalyticsViewState extends State<RoiAnalyticsView> {
  int _periodMonths = 3;

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
    final previousExpensesByCategory = <String, double>{};
    final expensesByCategory = <String, double>{};
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
        title: Text(AppText.tr(context, 'วิเคราะห์การใช้เงิน')),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppText.tr(context, 'ช่วงเวลาวิเคราะห์'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                            '$months เดือนล่าสุด',
                            english: 'Last $months months',
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
          Text(
            '${_formatMonth(context, currentStart)} - ${_formatMonth(context, _monthStart(now, 0))}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metric(
                AppText.tr(context, 'รายรับ'),
                income,
                Colors.green.shade700,
              ),
              _metric(
                AppText.tr(context, 'รายจ่าย'),
                expense,
                Colors.deepOrange,
              ),
              _metric(
                AppText.tr(context, 'เงินสุทธิ'),
                netCashFlow,
                Colors.indigo,
              ),
              _metric(
                AppText.tr(context, 'อัตรากำไรสุทธิ'),
                netMargin,
                Colors.teal,
                suffix: '%',
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionTitle(AppText.tr(context, 'กระแสเงินสดรายเดือน')),
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
                  Wrap(
                    spacing: 16,
                    children: [
                      _Legend(
                        color: Colors.green,
                        label: AppText.tr(context, 'รายรับ'),
                      ),
                      _Legend(
                        color: Colors.deepOrange,
                        label: AppText.tr(context, 'รายจ่าย'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(AppText.tr(context, 'เปรียบเทียบช่วงก่อนหน้า')),
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
                  title: Text(AppText.tr(context, 'รายจ่ายเทียบช่วงก่อนหน้า')),
                  subtitle: Text(
                    expenseChange == null
                        ? AppText.tr(
                            context,
                            'ยังไม่มีข้อมูลช่วงก่อนหน้าให้เปรียบเทียบ',
                          )
                        : AppText.tr(
                            context,
                            '${expenseChange.abs().toStringAsFixed(1)}% ${expenseChange > 0 ? 'เพิ่มขึ้น' : 'ลดลง'}',
                            english:
                                '${expenseChange.abs().toStringAsFixed(1)}% ${expenseChange > 0 ? 'increase' : 'decrease'}',
                          ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.compare_arrows,
                    color: Colors.indigo,
                  ),
                  title: Text(AppText.tr(context, 'เงินสุทธิช่วงนี้')),
                  subtitle: Text(
                    AppText.tr(
                      context,
                      '฿${netCashFlow.toStringAsFixed(2)} เทียบกับ ฿${(previousIncome - previousExpense).toStringAsFixed(2)} ในช่วงก่อนหน้า',
                      english:
                          '฿${netCashFlow.toStringAsFixed(2)} vs ฿${(previousIncome - previousExpense).toStringAsFixed(2)} in the previous period',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(AppText.tr(context, 'แจกแจงรายจ่ายตามหมวด')),
          if (rankedCategories.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  AppText.tr(
                    context,
                    'ยังไม่มีรายการรายจ่ายที่ยืนยันแล้วในช่วงนี้',
                  ),
                ),
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
                    title: Text(AppText.categoryLabel(context, entry.key)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: share),
                        const SizedBox(height: 4),
                        Text(
                          AppText.tr(
                            context,
                            '${(share * 100).toStringAsFixed(1)}% ของรายจ่าย${change == null ? '' : ' • ${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% เทียบช่วงก่อน'}',
                            english:
                                '${(share * 100).toStringAsFixed(1)}% of expenses${change == null ? '' : ' • ${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% vs previous period'}',
                          ),
                        ),
                      ],
                    ),
                    trailing: Text('฿${entry.value.toStringAsFixed(0)}'),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 16),
          _sectionTitle(AppText.tr(context, 'คำแนะนำจากรายการจริง')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _recommendation(
                  context,
                  income: income,
                  expense: expense,
                  netCashFlow: netCashFlow,
                  topCategory: topCategory,
                  highestExpense: highestExpense,
                ),
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

  String _formatMonth(BuildContext context, DateTime month) =>
      AppText.formatMonth(
        context,
        month,
        useBuddhistYear: widget.preferences?.useBuddhistYear ?? true,
      );

  String _recommendation(
    BuildContext context, {
    required double income,
    required double expense,
    required double netCashFlow,
    required MapEntry<String, double>? topCategory,
    required TransactionModel? highestExpense,
  }) {
    if (income == 0 && expense == 0) {
      return AppText.tr(
        context,
        'ยังไม่มีรายการที่ยืนยันในช่วงนี้ เพิ่มหรือยืนยันรายการเพื่อเริ่มวิเคราะห์',
        english: 'No confirmed transactions in this period. Add or confirm transactions to start analysis.',
      );
    }
    if (netCashFlow < 0) {
      return AppText.tr(
        context,
        'รายจ่ายสูงกว่ารายรับ ฿${(-netCashFlow).toStringAsFixed(2)} ในช่วงที่เลือก เริ่มตรวจหมวด ${AppText.categoryLabel(context, topCategory?.key ?? 'รายจ่าย')} ซึ่งใช้เงิน ฿${(topCategory?.value ?? 0).toStringAsFixed(2)} ก่อน',
        english:
            'Expenses exceed income by ฿${(-netCashFlow).toStringAsFixed(2)}. Start by reviewing ${AppText.categoryLabel(context, topCategory?.key ?? 'รายจ่าย')} (฿${(topCategory?.value ?? 0).toStringAsFixed(2)}).',
      );
    }
    if (topCategory != null && expense > 0) {
      final share = topCategory.value / expense * 100;
      final largestMessage = highestExpense == null
          ? ''
          : ' รายการรายจ่ายสูงสุดคือ "${highestExpense.title}" ฿${highestExpense.amount.toStringAsFixed(2)}.';
      return AppText.tr(
        context,
        'เงินสุทธิเป็นบวก ฿${netCashFlow.toStringAsFixed(2)}. หมวด ${AppText.categoryLabel(context, topCategory.key)} ใช้ ${share.toStringAsFixed(1)}% ของรายจ่ายทั้งหมด พิจารณาตรวจราคา/ปริมาณซื้อในหมวดนี้.$largestMessage',
        english:
            'Net cash flow is positive at ฿${netCashFlow.toStringAsFixed(2)}. ${AppText.categoryLabel(context, topCategory.key)} is ${share.toStringAsFixed(1)}% of expenses; review supplier prices and order quantities.$largestMessage',
      );
    }
    return AppText.tr(
      context,
      'ยังไม่มีรายจ่ายในช่วงนี้ รักษาการบันทึกรายการให้ครบเพื่อเห็นต้นทุนจริง',
      english: 'No expenses in this period. Keep records complete to understand actual costs.',
    );
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
      return Center(
        child: Text(AppText.tr(context, 'ยังไม่มีข้อมูลในช่วงเวลานี้')),
      );
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
