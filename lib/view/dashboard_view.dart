// Directory: lib/view/
// File: dashboard_view.dart

import 'package:flutter/material.dart';

import '../control/app_preferences.dart';
import '../control/account_controller.dart';
import '../l10n/app_text.dart';
import '../model/transaction.dart';
import '../service/api_service.dart';

class DashboardView extends StatelessWidget {
  final AccountController controller;
  final VoidCallback? onOpenReviewPending;
  final AppPreferences? preferences;

  const DashboardView({
    super.key,
    required this.controller,
    this.onOpenReviewPending,
    this.preferences,
  });

  Future<void> _handleUpload(BuildContext context) async {
    try {
      final images = await ApiService.pickMultipleSlips();
      if (images.isEmpty || !context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppText.tr(
              context,
              'กำลังอ่านสลิปจำนวน ${images.length} ใบ...',
              english: 'Reading ${images.length} slip(s)...',
            ),
          ),
        ),
      );
      final result = await ApiService.processAndSaveSlips(
        images,
        controller.userId,
        bookletId: controller.selectedBookletId,
      );
      if (!context.mounted) return;

      final summary = StringBuffer(
        AppText.tr(
          context,
          'บันทึก ${result.savedCount} ใบ • ซ้ำ ${result.duplicateCount} ใบ',
          english:
              'Saved ${result.savedCount} • duplicates ${result.duplicateCount}',
        ),
      );
      if (result.offlineCount > 0) {
        summary.write(
          AppText.tr(
            context,
            ' • Offline รอตรวจ ${result.offlineCount} ใบ',
            english: ' • Offline review ${result.offlineCount}',
          ),
        );
      }
      if (result.errors.isNotEmpty) {
        summary.write(
          AppText.tr(
            context,
            ' • ล้มเหลว ${result.errors.length} ใบ: ${result.errors.first}',
            english:
                ' • Failed ${result.errors.length}: ${result.errors.first}',
          ),
        );
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(summary.toString())));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${AppText.tr(context, 'อัปโหลดสลิปไม่สำเร็จ')}: $error',
            ),
          ),
        );
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
    final availableCategories = {
      ...controller.categoryTags,
      selectedCategory,
    }.toList();

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
                  Text(
                    AppText.tr(context, 'แก้ไข / ลบ รายการเก่า'),
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
                decoration: InputDecoration(
                  labelText: AppText.tr(context, 'ชื่อรายการ'),
                ),
              ),
              TextField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: AppText.tr(context, 'จำนวนเงิน (บาท)'),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                AppText.tr(context, 'ประเภทรายการ:'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  ChoiceChip(
                    label: Text(AppText.tr(context, 'รายจ่าย')),
                    selected: selectedType == 'expense',
                    onSelected: (val) =>
                        setModalState(() => selectedType = 'expense'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(AppText.tr(context, 'รายรับ')),
                    selected: selectedType == 'income',
                    onSelected: (val) =>
                        setModalState(() => selectedType = 'income'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(AppText.tr(context, 'โอนภายใน')),
                    selected: selectedType == 'internal_transfer',
                    onSelected: (val) =>
                        setModalState(() => selectedType = 'internal_transfer'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                AppText.tr(context, 'หมวดหมู่:'),
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
                      label: Text(AppText.tr(context, 'ลบรายการ')),
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
                      label: Text(AppText.tr(context, 'บันทึกแก้ไข')),
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
            if (controller.pendingCount > 0) ...[
              Card(
                child: ListTile(
                  leading: Badge(
                    label: Text('${controller.pendingCount}'),
                    child: const Icon(Icons.receipt_long_outlined),
                  ),
                  title: Text(AppText.tr(context, 'มีรายการรอตรวจ')),
                  subtitle: Text(
                    AppText.tr(
                      context,
                      'ตรวจยอดและรายละเอียดสลิปก่อนยืนยันลงบัญชี',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onOpenReviewPending,
                ),
              ),
              const SizedBox(height: 12),
            ],
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
                    Text(
                      AppText.tr(context, 'สรุปงบกำไร - ขาดทุน สุทธิ'),
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
                            Text(
                              AppText.tr(context, 'รายรับรวม'),
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
                            Text(
                              AppText.tr(context, 'รายจ่ายรวม'),
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
                    Row(
                      children: [
                        Icon(Icons.psychology, color: Colors.purple),
                        SizedBox(width: 8),
                        Text(
                          AppText.tr(
                            context,
                            'AI ที่ปรึกษาการเงินธุรกิจรายย่อย',
                          ),
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
                      controller.generateAIAdvice(
                        english:
                            Localizations.localeOf(context).languageCode ==
                            'en',
                      ),
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
                title: Text(AppText.tr(context, 'ผู้ช่วยบันทึกการเงิน')),
                subtitle: Text(
                  _recordingStreak() == 0
                      ? AppText.tr(
                          context,
                          'วันนี้ยังไม่มีรายการที่ยืนยัน เริ่มจดรายการเพื่อให้เห็นกระแสเงินสดครบขึ้น',
                          english: 'No confirmed transactions today. Record one to keep your cash flow up to date.',
                        )
                      : AppText.tr(
                          context,
                          'บันทึกต่อเนื่อง ${_recordingStreak()} วันแล้ว ข้อมูลครบช่วยให้คำแนะนำและรายงานแม่นขึ้น',
                          english:
                              'You have recorded transactions for ${_recordingStreak()} days. Complete data improves insights.',
                        ),
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
                label: Text(AppText.tr(context, 'อัปโหลดสลิปเพื่อบันทึกบัญชี')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              AppText.tr(context, 'ประวัติรายการบัญชี (กดเพื่อแก้ไข/ลบ)'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // รายการธุรกรรมทั้งหมด
            controller.transactions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(AppText.tr(context, 'ยังไม่มีรายการสลิป')),
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
                            '${AppText.tr(context, 'หมวด')}: ${item.category} • ${AppText.formatDate(context, item.date, useBuddhistYear: preferences?.useBuddhistYear ?? true)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isInternal
                                    ? AppText.tr(context, 'โอนภายใน')
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
