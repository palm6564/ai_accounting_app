// Directory: lib/model/
// File: shared_bill.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class BillParticipant {
  final String id;
  final String name;
  final double shareAmount;
  final bool isPaid;

  const BillParticipant({
    required this.id,
    required this.name,
    required this.shareAmount,
    required this.isPaid,
  });

  factory BillParticipant.fromMap(Map<String, dynamic> data) {
    return BillParticipant(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? 'ผู้ร่วมจ่าย',
      shareAmount: (data['shareAmount'] as num?)?.toDouble() ?? 0,
      isPaid: data['isPaid'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'shareAmount': shareAmount,
    'isPaid': isPaid,
  };
}

class SharedBillModel {
  final String id;
  final String title;
  final String bookletId;
  final String category;
  final double totalAmount;
  final DateTime date;
  final List<BillParticipant> participants;

  const SharedBillModel({
    required this.id,
    required this.title,
    required this.bookletId,
    required this.category,
    required this.totalAmount,
    required this.date,
    required this.participants,
  });

  factory SharedBillModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final rawParticipants = data['participants'] as List<dynamic>? ?? [];
    final dateValue = data['date'];
    return SharedBillModel(
      id: doc.id,
      title: data['title'] as String? ?? 'ค่าใช้จ่ายร่วม',
      bookletId: data['bookletId'] as String? ?? 'business',
      category: data['category'] as String? ?? 'ทั่วไป',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      date: dateValue is Timestamp ? dateValue.toDate() : DateTime.now(),
      participants: rawParticipants
          .whereType<Map<String, dynamic>>()
          .map(BillParticipant.fromMap)
          .toList(),
    );
  }
}
