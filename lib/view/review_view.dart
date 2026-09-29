// Directory: lib/view/
// File: review_view.dart

import 'package:flutter/material.dart';

import '../control/account_controller.dart';
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
                  const Text(
                    'ตรวจทานสลิป (Human Confirm)',
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
                decoration: const InputDecoration(labelText: 'ชื่อรายการ'),
              ),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'จำนวนเงิน (บาท)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              const Text(
                'เลือกหมวดหมู่บัญชี:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                children: ['ค่าแรง', 'วัตถุดิบ', 'ลูกค้า', 'ทั่วไป'].map((cat) {
                  return ChoiceChip(
                    label: Text(cat),
                    selected: selectedCategory == cat,
                    onSelected: (selected) =>
                        setModalState(() => selectedCategory = cat),
                  );
                }).toList(),
              ),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'หมายเหตุ'),
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
                      child: const Text('ลบรายการ'),
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
                      child: const Text('ยืนยันลงบัญชี'),
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

  void _showAddSharedBillDialog(BuildContext context) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final participantsController = TextEditingController();
    final categoryController = TextEditingController(text: 'ทั่วไป');

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('บันทึกค่าใช้จ่ายที่หารกัน'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'รายการ'),
              ),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'ยอดรวมที่จ่ายจริง (บาท)',
                ),
              ),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'หมวดหมู่'),
              ),
              TextField(
                controller: participantsController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อผู้ร่วมจ่าย คั่นด้วยจุลภาค',
                  hintText: 'เช่น เมย์, ต้น, นัท',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text.trim());
              final names = participantsController.text
                  .split(',')
                  .map((name) => name.trim())
                  .where((name) => name.isNotEmpty)
                  .toList();
              final title = titleController.text.trim();
              if (title.isEmpty ||
                  amount == null ||
                  amount <= 0 ||
                  names.isEmpty) {
                return;
              }
              await controller.createSharedBill(
                title: title,
                totalAmount: amount,
                category: categoryController.text,
                participantNames: names,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('บันทึกและหารเท่ากัน'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingList = controller.pendingTransactions;
    final bills = controller.sharedBills;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'งานการเงินที่ต้องติดตาม',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              onPressed: () => _showAddSharedBillDialog(context),
              tooltip: 'เพิ่มบิลหารค่าใช้จ่าย',
              icon: const Icon(Icons.group_add_outlined),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'ตรวจรายการที่ AI ยังไม่มั่นใจ และติดตามเงินที่ผู้ร่วมจ่ายยังค้างอยู่',
        ),
        const SizedBox(height: 16),
        const Text(
          'สลิปที่ต้องตรวจสอบ',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (pendingList.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.check_circle_outline, color: Colors.green),
              title: Text('ไม่มีสลิปรอตรวจ'),
              subtitle: Text('รายการที่ต้องตรวจจะปรากฏที่นี่'),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'บิลหารและยอดค้างรับ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Text('${controller.unpaidShareCount} คนค้าง'),
          ],
        ),
        if (bills.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.groups_outlined),
              title: Text('ยังไม่มีบิลหารค่าใช้จ่าย'),
              subtitle: Text('เพิ่มบิลเพื่อคำนวณส่วนแบ่งและติดตามการชำระ'),
            ),
          )
        else
          ...bills.map((bill) {
            final paidTotal = bill.participants
                .where((participant) => participant.isPaid)
                .fold(0.0, (sum, participant) => sum + participant.shareAmount);
            return Card(
              margin: const EdgeInsets.only(top: 8),
              child: ExpansionTile(
                title: Text(bill.title),
                subtitle: Text(
                  'รวม ฿${bill.totalAmount.toStringAsFixed(2)} • '
                  'รับคืนแล้ว ฿${paidTotal.toStringAsFixed(2)}',
                ),
                children: bill.participants.map((participant) {
                  return ListTile(
                    title: Text(participant.name),
                    subtitle: Text(
                      participant.isPaid ? 'ชำระแล้ว' : 'ยังไม่ชำระ',
                    ),
                    trailing: Text(
                      '฿${participant.shareAmount.toStringAsFixed(2)}',
                    ),
                    onTap: participant.isPaid
                        ? null
                        : () async {
                            await controller.markSharePaid(
                              billId: bill.id,
                              participantId: participant.id,
                            );
                          },
                  );
                }).toList(),
              ),
            );
          }),
        const SizedBox(height: 20),
      ],
    );
  }
}
