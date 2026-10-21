import 'package:ai_accounting_app/service/slip/slip_config.dart';
import 'package:ai_accounting_app/service/slip/slip_reader.dart';
import 'package:ai_accounting_app/service/slip/slip_server_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ผลจริงจาก Space (สลิปกสิกรจ่ายบิล 18 บาท)
  final json = <String, dynamic>{
    'amount': 18.0,
    'amount_flag': '',
    'from_name': 'นาย ภาสกร ป',
    'to_name': 'บริษัท ซันเวนดิ้ง เทคโนโลยี จำกัด',
    'bank': 'ธ. .กสิกรไทย',
    'title': 'จ่ายบิลสำเร็จ 1 ต.ค. 69  13:21 น.',
    'memo': null,
    'date': '1 ต.ค. 69 13:21',
    'ref_no': null,
    'retry': '',
    'seconds': 4.63,
  };

  test('readFromJson maps server fields to SlipRead', () {
    final read = SlipServerReader.readFromJson(json);
    expect(read.isSlip, isTrue);
    expect(read.amount, 18.0); // ไม่ใช่ 180 (ต้องส่ง "18.00" เข้า parseMoney)
    expect(read.fromName, 'นาย ภาสกร ป');
    expect(read.toName, 'บริษัท ซันเวนดิ้ง เทคโนโลยี จำกัด');
    expect(read.timeText, '13:21');
    expect(read.typeGuess, 'expense');
  });

  test('flags from the server keep the slip below verified', () {
    final scorer = SlipReader();
    final flagged = SlipServerReader.scoreJson(<String, dynamic>{
      ...json,
      'ref_no': 'A1B2C3D4E5F6',
      'amount_flag': 'minor_conflict',
      'retry': 'to_name',
    }, scorer);
    expect(flagged.score, lessThan(SlipConfig.verifiedScore));
    expect(flagged.issues.join(' '), contains('minor_conflict'));
    expect(flagged.issues.join(' '), contains('to_name'));
    expect(flagged.source, 'slip_server');
  });

  test('missing amount gives zero score', () {
    final scored = SlipServerReader.scoreJson(<String, dynamic>{
      ...json,
      'amount': null,
      'amount_flag': 'no_amount',
    }, SlipReader());
    expect(scored.read.amount, isNull);
    expect(scored.score, 0.0);
  });
}
