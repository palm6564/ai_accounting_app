// Directory: lib/control/
// File: account_controller.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/booklet.dart';
import '../model/shared_bill.dart';
import '../model/transaction.dart';

class AccountController extends ChangeNotifier {
  final String userId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<TransactionModel> _allTransactions = [];
  List<BookletModel> booklets = [];
  List<SharedBillModel> _allSharedBills = [];
  String selectedBookletId = 'business';
  bool isLoading = true;
  bool _creatingDefaultBooklet = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  List<TransactionModel> get transactions => _allTransactions
      .where((transaction) => transaction.bookletId == selectedBookletId)
      .toList();

  List<SharedBillModel> get sharedBills => _allSharedBills
      .where((bill) => bill.bookletId == selectedBookletId)
      .toList();

  AccountController({required this.userId}) {
    _listenToTransactions();
    _listenToBooklets();
    _listenToSharedBills();
    _loadSelectedBooklet();
  }

  void _listenToTransactions() {
    _subscriptions.add(
      _db
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .orderBy('date', descending: true)
          .snapshots()
          .listen((snapshot) {
            _allTransactions = snapshot.docs
                .map((doc) => TransactionModel.fromFirestore(doc))
                .toList();
            isLoading = false;
            notifyListeners();
          }),
    );
  }

  void _listenToBooklets() {
    _subscriptions.add(
      _db
          .collection('users')
          .doc(userId)
          .collection('booklets')
          .snapshots()
          .listen((snapshot) {
            booklets = snapshot.docs.map(BookletModel.fromFirestore).toList();
            if (booklets.isEmpty && !_creatingDefaultBooklet) {
              _creatingDefaultBooklet = true;
              _db
                  .collection('users')
                  .doc(userId)
                  .collection('booklets')
                  .doc('business')
                  .set({
                    'name': 'ธุรกิจร้านค้า',
                    'createdAt': FieldValue.serverTimestamp(),
                  })
                  .whenComplete(() => _creatingDefaultBooklet = false);
            }
            if (booklets.any((booklet) => booklet.id == selectedBookletId)) {
              notifyListeners();
            } else if (booklets.isNotEmpty) {
              selectedBookletId = booklets.first.id;
              notifyListeners();
            }
          }),
    );
  }

  void _listenToSharedBills() {
    _subscriptions.add(
      _db
          .collection('users')
          .doc(userId)
          .collection('sharedBills')
          .orderBy('date', descending: true)
          .snapshots()
          .listen((snapshot) {
            _allSharedBills = snapshot.docs
                .map(SharedBillModel.fromFirestore)
                .toList();
            notifyListeners();
          }),
    );
  }

  Future<void> _loadSelectedBooklet() async {
    final preference = await _db
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('preferences')
        .get();
    final savedId = preference.data()?['activeBookletId'] as String?;
    if (savedId != null) {
      selectedBookletId = savedId;
      notifyListeners();
    }
  }

  Future<void> createBooklet(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return;
    final doc = _db
        .collection('users')
        .doc(userId)
        .collection('booklets')
        .doc();
    await doc.set({
      'name': normalizedName,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await selectBooklet(doc.id);
  }

  Future<void> selectBooklet(String bookletId) async {
    selectedBookletId = bookletId;
    notifyListeners();
    await _db
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('preferences')
        .set({'activeBookletId': bookletId}, SetOptions(merge: true));
    notifyListeners();
  }

  Stream<Map<String, dynamic>?> watchWalletSettings(String bookletId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('booklets')
        .doc(bookletId)
        .collection('settings')
        .doc('walletBudget')
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  Future<void> saveWalletSettings({
    required String bookletId,
    required double monthlyBudget,
    required List<Map<String, dynamic>> wallets,
    required List<Map<String, dynamic>> recurringItems,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('booklets')
        .doc(bookletId)
        .collection('settings')
        .doc('walletBudget')
        .set({
          'monthlyBudget': monthlyBudget,
          'wallets': wallets,
          'recurringItems': recurringItems,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  // คำนวณยอดเงิน
  double get totalIncome => transactions
      .where((t) => t.type == 'income' && t.status == 'verified')
      .fold(0.0, (total, item) => total + item.amount);

  double get totalExpense => transactions
      .where((t) => t.type == 'expense' && t.status == 'verified')
      .fold(0.0, (total, item) => total + item.amount);

  double get netProfit => totalIncome - totalExpense;

  List<TransactionModel> get pendingTransactions =>
      transactions.where((t) => t.status == 'pending_review').toList();

  int get pendingCount => pendingTransactions.length;

  int get unpaidShareCount => sharedBills.fold(
    0,
    (total, bill) =>
        total +
        bill.participants.where((participant) => !participant.isPaid).length,
  );

  int get actionCount => pendingCount + unpaidShareCount;

  String generateAIAdvice() {
    if (transactions.isEmpty) return 'ยังไม่มีข้อมูลเพียงพอสำหรับการวิเคราะห์';
    if (netProfit < 0) {
      return 'คำเตือน: เดือนนี้มีสภาวะขาดทุนสุทธิ แนะนำคุมงบหมวด "วัตถุดิบ" และ "ค่าแรง"';
    } else {
      return 'ผลประกอบการดี: กำไรสุทธิอยู่ในเกณฑ์ปกติ มีกระแสเงินสดหมุนเวียนเพียงพอ';
    }
  }

  // ฟังก์ชันแก้ไขรายการ (ใช้ได้ทั้งรายการเก่าและรายการใหม่)
  Future<void> updateTransaction({
    required String docId,
    required String title,
    required double amount,
    required String type,
    required String category,
    required String note,
    String status = 'verified',
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(docId)
        .update({
          'title': title,
          'amount': amount,
          'type': type,
          'category': category,
          'note': note,
          'status': status,
        });
  }

  // ฟังก์ชันลบรายการเก่าออก
  Future<void> deleteTransaction(String docId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(docId)
        .delete();
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    await _db.collection('users').doc(userId).collection('transactions').add({
      'title': transaction.title,
      'amount': transaction.amount,
      'type': transaction.type,
      'category': transaction.category,
      'note': transaction.note,
      'status': transaction.status,
      'confidence': transaction.confidence,
      'refNo': transaction.refNo,
      'date': Timestamp.fromDate(transaction.date),
      'bookletId': transaction.bookletId == 'business'
          ? selectedBookletId
          : transaction.bookletId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createSharedBill({
    required String title,
    required double totalAmount,
    required String category,
    required List<String> participantNames,
  }) async {
    if (participantNames.isEmpty || totalAmount <= 0) return;
    final billRef = _db
        .collection('users')
        .doc(userId)
        .collection('sharedBills')
        .doc();
    final transactionRef = _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc();
    final shareAmount = totalAmount / participantNames.length;
    final participants = participantNames.indexed.map((entry) {
      final (index, name) = entry;
      return BillParticipant(
        id: '${DateTime.now().microsecondsSinceEpoch}-$index',
        name: name,
        shareAmount: shareAmount,
        isPaid: false,
      );
    }).toList();
    final batch = _db.batch();
    batch.set(billRef, {
      'title': title.trim(),
      'category': category.trim().isEmpty ? 'ทั่วไป' : category.trim(),
      'bookletId': selectedBookletId,
      'totalAmount': totalAmount,
      'date': Timestamp.fromDate(DateTime.now()),
      'participants': participants
          .map((participant) => participant.toMap())
          .toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(transactionRef, {
      'title': title.trim(),
      'amount': totalAmount,
      'type': 'expense',
      'category': category.trim().isEmpty ? 'ทั่วไป' : category.trim(),
      'note': 'บันทึกค่าใช้จ่ายร่วม',
      'status': 'verified',
      'confidence': 1.0,
      'refNo': '',
      'date': Timestamp.fromDate(DateTime.now()),
      'bookletId': selectedBookletId,
      'sharedBillId': billRef.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> markSharePaid({
    required String billId,
    required String participantId,
  }) async {
    final billRef = _db
        .collection('users')
        .doc(userId)
        .collection('sharedBills')
        .doc(billId);
    final transactionRef = _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc();
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(billRef);
      final data = snapshot.data();
      if (data == null) return;
      final rawParticipants = data['participants'] as List<dynamic>? ?? [];
      final participants = rawParticipants
          .whereType<Map<String, dynamic>>()
          .map(BillParticipant.fromMap)
          .toList();
      final index = participants.indexWhere(
        (participant) => participant.id == participantId,
      );
      if (index < 0 || participants[index].isPaid) return;
      final participant = participants[index];
      participants[index] = BillParticipant(
        id: participant.id,
        name: participant.name,
        shareAmount: participant.shareAmount,
        isPaid: true,
      );
      transaction.update(billRef, {
        'participants': participants.map((entry) => entry.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(transactionRef, {
        'title': 'รับคืน: ${data['title'] ?? 'ค่าใช้จ่ายร่วม'}',
        'amount': participant.shareAmount,
        'type': 'income',
        'category': 'ชำระคืนค่าใช้จ่าย',
        'note': 'รับชำระจาก ${participant.name}',
        'status': 'verified',
        'confidence': 1.0,
        'refNo': '',
        'date': Timestamp.fromDate(DateTime.now()),
        'bookletId': data['bookletId'] ?? 'business',
        'sharedBillId': billId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
