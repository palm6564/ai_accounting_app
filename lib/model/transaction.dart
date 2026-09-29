// Directory: lib/model/
// File: transaction.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final String type; // 'income', 'expense', หรือ 'internal_transfer'
  final String category; // 'ค่าแรง', 'วัตถุดิบ', 'ลูกค้า', 'ทั่วไป'
  final String note;
  final String status; // 'pending_review' หรือ 'verified'
  final double confidence; // ค่าความมั่นใจ AI
  final String refNo; // เลขอ้างอิงตัดสลิปซ้ำ
  final DateTime date;
  final String bookletId;

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.note,
    required this.status,
    required this.confidence,
    required this.refNo,
    required this.date,
    this.bookletId = 'business',
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TransactionModel(
      id: doc.id,
      title: data['title'] ?? 'ไม่มีชื่อรายการ',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      type: data['type'] ?? 'expense',
      category: data['category'] ?? 'ทั่วไป',
      note: data['note'] ?? '',
      status: data['status'] ?? 'verified',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 1.0,
      refNo: data['refNo'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      bookletId: data['bookletId'] as String? ?? 'business',
    );
  }
}
