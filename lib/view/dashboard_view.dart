// Directory: lib/view/
// File: dashboard_view.dart

import 'package:flutter/material.dart';

import '../control/account_controller.dart';
import '../model/transaction.dart';
import '../service/api_service.dart';

class DashboardView extends StatelessWidget {
  final AccountController controller;

  const DashboardView({super.key, required this.controller});

  Future<void> _handleUpload(BuildContext context) async {
    try {
      final images = await ApiService.pickMultipleSlips();
      if (images.isEmpty || !context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('กำลังอ่านสลิปจำนวน ${images.length} ใบ...')),
      );
      final result = await ApiService.processAndSaveSlips(
        images,
        controller.userId,
        bookletId: controller.selectedBookletId,
      );
      if (!context.mounted) return;

      final summary = StringBuffer(
        'บันทึก ${result.savedCount} ใบ • ซ้ำ ${result.duplicateCount} ใบ',
      );
      if (result.offlineCount > 0) {
        summary.write(' • Offline รอตรวจ ${result.offlineCount} ใบ');
      }
      if (result.errors.isNotEmpty) {
        summary.write(
          ' • ล้มเหลว ${result.errors.length} ใบ: ${result.errors.first}',
        );
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(summary.toString())));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('อัปโหลดสลิปไม่สำเร็จ: $error')));
    }
  }

  int _recordingStreak() {
    final recordedDays = controller.transactions
        .where((transaction) => transaction.status == 'verified')
        .map(
          (transaction) => DateTime(
            transaction.date.year,
            transaction.date.month,
            transaction.date.day,
          ),
        )
        .toSet();
    final today = DateTime.now();
    var checkDay = DateTime(today.year, today.month, today.day);
    if (!recordedDays.contains(checkDay)) {
      checkDay = checkDay.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (recordedDays.contains(checkDay)) {
      streak++;
      checkDay = checkDay.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // หน้าต่าง Popup แก้ไข/ลบข้อมูลรายการเก่า
  void _showEditOrDeleteDialog(BuildContext context, TransactionModel item) {
    final titleController = TextEditingController(text: item.title);
    final amountController = TextEditingController(
      text: item.amount.toString(),
    );
    final noteController = TextEditingController(text: item.note);
    String selectedType = item.type;
    String selectedCategory = item.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                    'แก้ไข / ลบ รายการเก่า',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'ชื่อรายการ'),
              ),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'จำนวนเงิน (บาท)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              const Text(
                'ประเภทรายการ:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('รายจ่าย'),
                    selected: selectedType == 'expense',
                    onSelected: (val) =>
                        setModalState(() => selectedType = 'expense'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('รายรับ'),
                    selected: selectedType == 'income',
                    onSelected: (val) =>
                        setModalState(() => selectedType = 'income'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('โอนภายใน'),
                    selected: selectedType == 'internal_transfer',
                    onSelected: (val) =>
                        setModalState(() => selectedType = 'internal_transfer'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              const Text(
                'หมวดหมู่:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                children: ['วัตถุดิบ', 'ค่าแรง', 'ลูกค้า', 'ทั่วไป'].map((cat) {
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
              const SizedBox(height: 24),

              Row(
                children: [
                  // ปุ่มลบรายการ
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await controller.deleteTransaction(item.id);
                        if (context.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text('ลบรายการ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ปุ่มบันทึกการแก้ไข
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await controller.updateTransaction(
                          docId: item.id,
                          title: titleController.text,
                          amount:
                              double.tryParse(amountController.text) ??
                              item.amount,
                          type: selectedType,
                          category: selectedCategory,
                          note: noteController.text,
                        );
                        if (context.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: const Text('บันทึกแก้ไข'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
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
    return RefreshIndicator(
      onRefresh: () async {},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // การ์ดงบกำไร - ขาดทุน + ROI Tracker
            Card(
              color: Colors.indigo.shade900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text(
                      'สรุปงบกำไร - ขาดทุน สุทธิ',
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '฿${controller.netProfit.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: controller.netProfit >= 0
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 24),

                    // แสดง รายรับรวม | รายจ่ายรวม
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'รายรับรวม',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '฿${controller.totalIncome.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text(
                              'รายจ่ายรวม',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '฿${controller.totalExpense.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // การ์ด AI Advisor
            Card(
              color: Colors.purple.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.psychology, color: Colors.purple),
                        SizedBox(width: 8),
                        Text(
                          'AI ที่ปรึกษาการเงินธุรกิจรายย่อย',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.generateAIAdvice(),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.teal.shade50,
              child: ListTile(
                leading: const Icon(
                  Icons.emoji_emotions_outlined,
                  color: Colors.teal,
                ),
                title: const Text('ผู้ช่วยบันทึกการเงิน'),
                subtitle: Text(
                  _recordingStreak() == 0
                      ? 'วันนี้ยังไม่มีรายการที่ยืนยัน เริ่มจดรายการเพื่อให้เห็นกระแสเงินสดครบขึ้น'
                      : 'บันทึกต่อเนื่อง ${_recordingStreak()} วันแล้ว '
                            'ข้อมูลครบช่วยให้คำแนะนำและรายงานแม่นขึ้น',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ปุ่มอัปโหลดสลิป
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _handleUpload(context),
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('อัปโหลดสลิปเพื่อบันทึกบัญชี'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'ประวัติรายการบัญชี (กดเพื่อแก้ไข/ลบ)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // รายการธุรกรรมทั้งหมด
            controller.transactions.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('ยังไม่มีรายการสลิป'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: controller.transactions.length,
                    itemBuilder: (context, index) {
                      final item = controller.transactions[index];
                      final isInternal = item.type == 'internal_transfer';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => _showEditOrDeleteDialog(
                            context,
                            item,
                          ), // กดที่รายการเพื่อแก้ไขหรือลบ
                          leading: CircleAvatar(
                            backgroundColor: isInternal
                                ? Colors.grey.shade200
                                : (item.type == 'income'
                                      ? Colors.green.shade50
                                      : Colors.indigo.shade50),
                            child: Icon(
                              isInternal
                                  ? Icons.swap_horiz
                                  : (item.type == 'income'
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward),
                              color: isInternal
                                  ? Colors.grey
                                  : (item.type == 'income'
                                        ? Colors.green
                                        : Colors.indigo),
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'หมวด: ${item.category} • ${item.date.day}/${item.date.month}/${item.date.year}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isInternal
                                    ? 'โอนภายใน'
                                    : '${item.type == 'expense' ? '-' : '+'}฿${item.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: isInternal
                                      ? Colors.grey
                                      : (item.type == 'expense'
                                            ? Colors.red
                                            : Colors.green),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.edit_note, color: Colors.grey),
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
}
