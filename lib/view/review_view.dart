// Directory: lib/view/
// File: review_view.dart

import 'package:flutter/material.dart';

import '../control/account_controller.dart';
import '../l10n/app_text.dart';
import '../model/transaction.dart';

class ReviewView extends StatelessWidget {
  final AccountController controller;

  const ReviewView({super.key, required this.controller});

  void _showEditBottomSheet(BuildContext context, TransactionModel item) {
    final titleController = TextEditingController(text: item.title);
    final amountController = TextEditingController(
      text: item.amount.toString(),
    );
    final noteController = TextEditingController(text: item.note);
    String selectedCategory = item.category;
    final availableCategories = {
      ...controller.categoryTags,
      selectedCategory,
    }.toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppText.tr(context, 'ตรวจทานสลิป (Human Confirm)'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Chip(
                    label: Text(
                      'Conf: ${(item.confidence * 100).toStringAsFixed(0)}%',
                    ),
                    backgroundColor: Colors.orange.shade100,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: AppText.tr(context, 'ชื่อรายการ'),
                ),
              ),
              TextField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: AppText.tr(context, 'จำนวนเงิน (บาท)'),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Text(
                AppText.tr(context, 'เลือกหมวดหมู่บัญชี:'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                children: availableCategories.map((cat) {
                  return ChoiceChip(
                    label: Text(AppText.categoryLabel(context, cat)),
                    selected: selectedCategory == cat,
                    onSelected: (selected) =>
                        setModalState(() => selectedCategory = cat),
                  );
                }).toList(),
              ),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: AppText.tr(context, 'หมายเหตุ'),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        controller.deleteTransaction(item.id);
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: Text(AppText.tr(context, 'ลบรายการ')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        controller.updateTransaction(
                          docId: item.id,
                          title: titleController.text,
                          amount:
                              double.tryParse(amountController.text) ??
                              item.amount,
                          type: item.type,
                          category: selectedCategory,
                          note: noteController.text,
                        );
                        Navigator.pop(ctx);
                      },
                      child: Text(AppText.tr(context, 'ยืนยันลงบัญชี')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingList = controller.pendingTransactions;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          AppText.tr(context, 'รายการที่ต้องตรวจ'),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(AppText.tr(context, 'ตรวจและแก้ข้อมูลสลิปก่อนยืนยันลงบัญชี')),
        if (pendingList.isEmpty)
          Card(
            child: ListTile(
              leading: Icon(Icons.check_circle_outline, color: Colors.green),
              title: Text(AppText.tr(context, 'ไม่มีสลิปรอตรวจ')),
              subtitle: Text(
                AppText.tr(context, 'รายการที่ต้องตรวจจะปรากฏที่นี่'),
              ),
            ),
          )
        else
          ...pendingList.map(
            (item) => Card(
              margin: const EdgeInsets.only(top: 8),
              child: ListTile(
                leading: const Icon(Icons.receipt_long, color: Colors.orange),
                title: Text(item.title),
                subtitle: Text(
                  '${item.category} • ความมั่นใจ ${(item.confidence * 100).toStringAsFixed(0)}%',
                ),
                trailing: Text('฿${item.amount.toStringAsFixed(2)}'),
                onTap: () => _showEditBottomSheet(context, item),
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}
