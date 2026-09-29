// Directory: lib/view/
// File: wallet_budget_view.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../control/account_controller.dart';
import '../model/transaction.dart';
import '../service/export_service.dart';

class WalletItem {
  final String id;
  final String name;
  final double balance;
  final int colorIndex;

  const WalletItem({
    required this.id,
    required this.name,
    required this.balance,
    required this.colorIndex,
  });

  factory WalletItem.fromMap(Map<String, dynamic> data) => WalletItem(
    id: data['id'] as String? ?? '',
    name: data['name'] as String? ?? 'กระเป๋าเงิน',
    balance: (data['balance'] as num?)?.toDouble() ?? 0,
    colorIndex: (data['colorIndex'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'balance': balance,
    'colorIndex': colorIndex,
  };
}

class RecurringItem {
  final String id;
  final String title;
  final double amount;
  final String category;
  final String dueDate;

  const RecurringItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.dueDate,
  });

  factory RecurringItem.fromMap(Map<String, dynamic> data) => RecurringItem(
    id: data['id'] as String? ?? '',
    title: data['title'] as String? ?? 'รายการจ่ายประจำ',
    amount: (data['amount'] as num?)?.toDouble() ?? 0,
    category: data['category'] as String? ?? 'ทั่วไป',
    dueDate: data['dueDate'] as String? ?? 'ทุกสิ้นเดือน',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'amount': amount,
    'category': category,
    'dueDate': dueDate,
  };
}

class WalletBudgetView extends StatefulWidget {
  final AccountController controller;

  const WalletBudgetView({super.key, required this.controller});

  @override
  State<WalletBudgetView> createState() => _WalletBudgetViewState();
}

class _WalletBudgetViewState extends State<WalletBudgetView> {
  double _monthlyBudget = 30000.0;
  final List<WalletItem> _wallets = [];
  final List<RecurringItem> _recurringItems = [];
  StreamSubscription<Map<String, dynamic>?>? _settingsSubscription;
  String? _loadedBookletId;
  static const _walletColors = [
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    _listenToWalletSettings();
  }

  @override
  void didUpdateWidget(covariant WalletBudgetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_loadedBookletId != widget.controller.selectedBookletId) {
      _listenToWalletSettings();
    }
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    super.dispose();
  }

  void _listenToWalletSettings() {
    _settingsSubscription?.cancel();
    final bookletId = widget.controller.selectedBookletId;
    _loadedBookletId = bookletId;
    setState(() {
      _monthlyBudget = 30000;
      _wallets.clear();
      _recurringItems.clear();
    });
    _settingsSubscription = widget.controller
        .watchWalletSettings(bookletId)
        .listen((settings) {
          if (!mounted || _loadedBookletId != bookletId || settings == null) {
            return;
          }
          final rawWallets = settings['wallets'] as List<dynamic>? ?? [];
          final rawRecurring =
              settings['recurringItems'] as List<dynamic>? ?? [];
          setState(() {
            _monthlyBudget =
                (settings['monthlyBudget'] as num?)?.toDouble() ?? 30000;
            _wallets
              ..clear()
              ..addAll(
                rawWallets.whereType<Map<String, dynamic>>().map(
                  WalletItem.fromMap,
                ),
              );
            _recurringItems
              ..clear()
              ..addAll(
                rawRecurring.whereType<Map<String, dynamic>>().map(
                  RecurringItem.fromMap,
                ),
              );
          });
        });
  }

  Future<void> _persistSettings() async {
    try {
      await widget.controller.saveWalletSettings(
        bookletId: widget.controller.selectedBookletId,
        monthlyBudget: _monthlyBudget,
        wallets: _wallets.map((wallet) => wallet.toMap()).toList(),
        recurringItems: _recurringItems.map((item) => item.toMap()).toList(),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกข้อมูลกระเป๋าไม่สำเร็จ: $error')),
      );
    }
  }

  double _getCurrentMonthExpense() {
    final now = DateTime.now();
    return widget.controller.transactions
        .where(
          (transaction) =>
              transaction.type == 'expense' &&
              transaction.status == 'verified' &&
              transaction.date.year == now.year &&
              transaction.date.month == now.month,
        )
        .fold(0.0, (total, transaction) => total + transaction.amount);
  }

  @override
  Widget build(BuildContext context) {
    final currentMonthExpense = _getCurrentMonthExpense();
    final budgetProgress = _monthlyBudget > 0
        ? currentMonthExpense / _monthlyBudget
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('กระเป๋าเงิน & งบประมาณ'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'ส่งออก CSV',
            onPressed: () {
              ExportService.exportTransactionsToCSV(
                widget.controller.transactions,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '💳 บัญชี & กระเป๋าเงิน',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => _showAddWalletDialog(context),
                  icon: const Icon(Icons.add_card),
                  label: const Text('เพิ่มกระเป๋า'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: _wallets.isEmpty
                  ? const Center(
                      child: Text(
                        'ยังไม่มีกระเป๋าเงิน เพิ่มบัญชีเพื่อเริ่มบันทึกยอด',
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _wallets.length,
                      itemBuilder: (context, index) =>
                          _buildWalletCard(_wallets[index]),
                    ),
            ),
            const SizedBox(height: 24),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '🎯 ควบคุมงบประมาณเดือนนี้',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showEditBudgetDialog(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ใช้จ่ายจริงเดือนนี้: ฿${currentMonthExpense.toStringAsFixed(2)}',
                        ),
                        Text(
                          'งบตั้งไว้: ฿${_monthlyBudget.toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: budgetProgress > 1.0 ? 1.0 : budgetProgress,
                      backgroundColor: Colors.grey.shade200,
                      color: budgetProgress >= 1.0
                          ? Colors.red
                          : budgetProgress > 0.8
                          ? Colors.orange
                          : Colors.indigo,
                      minHeight: 10,
                    ),
                    const SizedBox(height: 8),
                    if (budgetProgress >= 1.0)
                      const Text(
                        '🚨 เตือน: ค่าใช้จ่ายเดือนนี้เกินงบประมาณที่ตั้งไว้แล้ว!',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      )
                    else if (budgetProgress >= 0.8)
                      const Text(
                        '⚠️ เตือน: ค่าใช้จ่ายใกล้เต็มงบประมาณแล้ว',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🔄 รายการจ่ายประจำ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => _showAddRecurringDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่ม'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_recurringItems.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('ไม่มีรายการจ่ายประจำ')),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recurringItems.length,
                itemBuilder: (context, index) {
                  final item = _recurringItems[index];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.indigoAccent,
                        child: Icon(Icons.repeat, color: Colors.white),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'หมวด: ${item.category} | กำหนด: ${item.dueDate}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '-฿${item.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'pay') {
                                _executePayment(item);
                              } else if (value == 'delete') {
                                setState(() => _recurringItems.removeAt(index));
                                unawaited(_persistSettings());
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'pay',
                                child: Text('ลงบันทึกจ่ายแล้ว'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('ลบรายการ'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard(WalletItem wallet) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _walletColors[wallet.colorIndex % _walletColors.length].shade700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  wallet.name,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                tooltip: 'ลบกระเป๋า',
                onPressed: () => setState(() {
                  _wallets.removeWhere((item) => item.id == wallet.id);
                  unawaited(_persistSettings());
                }),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '฿${wallet.balance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executePayment(RecurringItem item) async {
    try {
      await widget.controller.addTransaction(
        TransactionModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: item.title,
          amount: item.amount,
          type: 'expense',
          category: item.category,
          note: 'จ่ายประจำ (${item.dueDate})',
          status: 'verified',
          confidence: 1.0,
          refNo: '',
          date: DateTime.now(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึกรายจ่าย "${item.title}" เรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('บันทึกรายจ่ายไม่สำเร็จ: $error')));
    }
  }

  void _showAddWalletDialog(BuildContext context) {
    final nameController = TextEditingController();
    final balanceController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เพิ่มกระเป๋าเงิน / บัญชี'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'ชื่อบัญชี/กระเป๋า'),
            ),
            TextField(
              controller: balanceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'ยอดเงินเริ่มต้น (บาท)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final balance = double.tryParse(balanceController.text.trim());
              if (name.isEmpty || balance == null || balance < 0) return;
              setState(() {
                _wallets.add(
                  WalletItem(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    name: name,
                    balance: balance,
                    colorIndex: _wallets.length,
                  ),
                );
              });
              unawaited(_persistSettings());
              Navigator.pop(context);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  void _showEditBudgetDialog(BuildContext context) {
    final controller = TextEditingController(text: _monthlyBudget.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ตั้งงบประมาณรายเดือน'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'จำนวนเงิน (บาท)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _monthlyBudget =
                    double.tryParse(controller.text) ?? _monthlyBudget;
              });
              unawaited(_persistSettings());
              Navigator.pop(ctx);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  void _showAddRecurringDialog(BuildContext context) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final categoryController = TextEditingController(text: 'ทั่วไป');
    final dueController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เพิ่มรายการจ่ายประจำ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'ชื่อรายการ'),
            ),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'จำนวนเงิน'),
            ),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: 'หมวดหมู่'),
            ),
            TextField(
              controller: dueController,
              decoration: const InputDecoration(
                labelText: 'รอบการจ่าย (เช่น ทุกวันที่ 5)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              final amount = double.tryParse(amountController.text.trim());
              if (title.isNotEmpty && amount != null && amount > 0) {
                setState(() {
                  _recurringItems.add(
                    RecurringItem(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      title: title,
                      amount: amount,
                      category: categoryController.text.trim().isEmpty
                          ? 'ทั่วไป'
                          : categoryController.text.trim(),
                      dueDate: dueController.text.trim().isEmpty
                          ? 'ทุกสิ้นเดือน'
                          : dueController.text.trim(),
                    ),
                  );
                });
                unawaited(_persistSettings());
              }
              Navigator.pop(ctx);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }
}
