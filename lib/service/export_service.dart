// Directory: lib/service/
// File: export_service.dart

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../model/transaction.dart';

class ExportService {
  static Future<void> exportTransactionsToCSV(
    List<TransactionModel> transactions,
  ) async {
    final csvData = StringBuffer();

    csvData.writeln(
      'ID,วันที่,ชื่อรายการ,ประเภท,หมวดหมู่,จำนวนเงิน(บาท),หมายเหตุ',
    );

    for (final item in transactions) {
      final dateStr = '${item.date.year}-${item.date.month}-${item.date.day}';
      csvData.writeln(
        '"${item.id}","$dateStr","${item.title}","${item.type}","${item.category}",${item.amount},"${item.note}"',
      );
    }

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/accounting_report_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString(csvData.toString());

    await Share.shareXFiles([XFile(path)], text: 'รายงานการเงิน AI Accounting');
  }
}
