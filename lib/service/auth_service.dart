// Directory: lib/service/
// File: auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required DateTime dateOfBirth,
  }) async {
    if (!isAtLeast18(dateOfBirth)) {
      throw FirebaseAuthException(
        code: 'underage',
        message: 'สมัครสมาชิกได้เมื่ออายุครบ 18 ปีบริบูรณ์',
      );
    }

    UserCredential credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    User? user = credential.user;

    if (user != null) {
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'name': name,
        'displayName': name,
        'tier': 'Free',
        'ageGatePassedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return user;
  }

  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    UserCredential credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  static bool isAtLeast18(DateTime dateOfBirth, {DateTime? now}) {
    final today = now ?? DateTime.now();
    var age = today.year - dateOfBirth.year;
    if (today.month < dateOfBirth.month ||
        (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) {
      age--;
    }
    return age >= 18 && !dateOfBirth.isAfter(today);
  }

  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    final normalizedName = name.trim();
    if (user == null) throw StateError('ไม่พบผู้ใช้ที่เข้าสู่ระบบ');
    if (normalizedName.isEmpty) throw ArgumentError('กรุณากรอกชื่อผู้ใช้');

    await user.updateDisplayName(normalizedName);
    await _db.collection('users').doc(user.uid).set({
      'displayName': normalizedName,
      'name': normalizedName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await user.reload();
  }

  Future<void> deleteCurrentAccount({required String password}) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('ไม่พบผู้ใช้ที่สามารถยืนยันตัวตนด้วยอีเมลได้');
    }

    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );

    final userRef = _db.collection('users').doc(user.uid);
    final booklets = await userRef.collection('booklets').get();
    for (final booklet in booklets.docs) {
      await _deleteCollectionDocuments(
        booklet.reference.collection('settings'),
      );
      await booklet.reference.delete();
    }

    await _deleteCollectionDocuments(userRef.collection('transactions'));
    await _deleteCollectionDocuments(userRef.collection('sharedBills'));
    await _deleteCollectionDocuments(userRef.collection('settings'));
    await userRef.delete();
    await user.delete();
  }

  Future<void> _deleteCollectionDocuments(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snapshot = await collection.limit(400).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _db.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }
}
