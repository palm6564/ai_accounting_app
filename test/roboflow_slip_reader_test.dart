import 'package:ai_accounting_app/service/slip/roboflow_slip_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseMoney handles OCR variants', () {
    expect(RoboflowSlipReader.parseMoney('1,250.00 บาท'), 1250.0);
    expect(RoboflowSlipReader.parseMoney('1250,00'), 1250.0);
    expect(RoboflowSlipReader.parseMoney('฿ 85'), 85.0);
    expect(RoboflowSlipReader.parseMoney('abc'), isNull);
  });

  test('buildRead maps field text to SlipRead', () {
    final read = RoboflowSlipReader.buildRead(<String, String>{
      'amount': '฿350.00',
      'date': '19 ต.ค. 2569 14:32',
      'ref_no': '0123ABC4567',
      'to_name': 'ไปยัง ร้านป้าเล็ก (24376)',
      'title': 'เติมเงินสำเร็จ',
    });
    expect(read.amount, 350.0);
    expect(read.timeText, '14:32');
    expect(read.toName, 'ร้านป้าเล็ก');
    expect(read.typeGuess, 'expense');
  });

  test('extractDate / extractRef from whole-slip text', () {
    const text =
        'โอนเงินสำเร็จ\nรหัสอ้างอิง Adda645661e434869\n'
        'โทร 0968164934\nวันที่ทำรายการ 17 ต.ค. 2569 - 18:59';
    expect(RoboflowSlipReader.extractRef(text), 'Adda645661e434869');
    expect(RoboflowSlipReader.extractRef('โทร 0968164934'), isNull);
    expect(RoboflowSlipReader.extractDate(text), '17 ต.ค. 2569 18:59');
  });
}
