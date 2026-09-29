// Directory: lib/model/
// File: booklet.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class BookletModel {
  final String id;
  final String name;

  const BookletModel({required this.id, required this.name});

  factory BookletModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return BookletModel(
      id: doc.id,
      name: doc.data()?['name'] as String? ?? 'สมุดบัญชี',
    );
  }
}
