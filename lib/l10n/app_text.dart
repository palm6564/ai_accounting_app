import 'package:flutter/material.dart';

class AppText {
  static String tr(BuildContext context, String thai, {String? english}) {
    if (Localizations.localeOf(context).languageCode != 'en') return thai;
    return english ?? _english[thai] ?? thai;
  }

  static String formatDate(
    BuildContext context,
    DateTime date, {
    bool useBuddhistYear = true,
  }) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    final year = date.year + (useBuddhistYear ? 543 : 0);
    if (isEnglish) {
      return '${date.month}/${date.day}/$year';
    }
    return '${date.day}/${date.month}/$year';
  }

  static String formatMonth(
    BuildContext context,
    DateTime month, {
    bool useBuddhistYear = true,
  }) {
    final year = month.year + (useBuddhistYear ? 543 : 0);
    return '${month.month}/$year';
  }

  static String categoryLabel(BuildContext context, String category) {
    if (Localizations.localeOf(context).languageCode != 'en') return category;
    return _categoryEnglish[category] ?? category;
  }

  static const _categoryEnglish = <String, String>{
    'วัตถุดิบ': 'Supplies',
    'ค่าแรง': 'Labor',
    'ลูกค้า': 'Customer',
    'ทั่วไป': 'General',
    'วัตถุดิบ/สินค้า': 'Inventory and supplies',
    'ค่าอาหาร': 'Meals',
    'ค่าเดินทาง': 'Travel',
    'สาธารณูปโภค': 'Utilities',
    'อุปกรณ์/บรรจุภัณฑ์': 'Equipment and packaging',
    'ค่าเช่า': 'Rent',
  };

  static const _english = <String, String>{
    'Dashboard บัญชี AI': 'AI Accounting Dashboard',
    'Dashboard': 'แดชบอร์ด',
    'Wallet': 'กระเป๋าเงิน',
    'ธุรกิจรายย่อย': 'Small Business',
    'วิเคราะห์': 'Analysis',
    'วิเคราะห์การใช้เงิน': 'Spending Analysis',
    'กระเป๋าเงิน & งบประมาณ': 'Wallet & Budget',
    'ตั้งค่า': 'Settings',
    'งานที่ต้องทำ': 'Tasks',
    'งาน': 'Tasks',
    'ดูกราฟและแนวโน้ม': 'View charts and trends',
    'เลือกสมุดบัญชี': 'Choose ledger',
    'สร้างสมุดบัญชีใหม่': 'Create a ledger',
    'สร้างสมุดบัญชี': 'Create ledger',
    'ชื่อสมุด เช่น เงินส่วนตัว หรือ ทริปเชียงใหม่':
        'Ledger name, e.g. Personal or Chiang Mai trip',
    'ยกเลิก': 'Cancel',
    'สร้าง': 'Create',
    'ตกลง': 'OK',
    'บันทึก': 'Save',
    'บันทึกแก้ไข': 'Save changes',
    'ลบรายการ': 'Delete transaction',
    'ยืนยันลงบัญชี': 'Confirm transaction',
    'ชื่อรายการ': 'Transaction name',
    'จำนวนเงิน (บาท)': 'Amount (THB)',
    'จำนวนเงิน': 'Amount',
    'รายจ่าย': 'Expense',
    'รายรับ': 'Income',
    'โอนภายใน': 'Internal transfer',
    'หมวดหมู่': 'Category',
    'เลือกหมวดหมู่บัญชี:': 'Choose a category:',
    'หมายเหตุ': 'Note',
    'แก้ไข / ลบ รายการเก่า': 'Edit or delete transaction',
    'ประเภทรายการ:': 'Transaction type:',
    'บัญชี & กระเป๋าเงิน': 'Accounts & wallets',
    'เพิ่มกระเป๋า': 'Add wallet',
    'เพิ่มกระเป๋าเงิน': 'Add wallet',
    'เพิ่มกระเป๋าเงิน / บัญชี': 'Add wallet or account',
    'ชื่อบัญชี/กระเป๋า': 'Account or wallet name',
    'ยอดเงินเริ่มต้น (บาท)': 'Starting balance (THB)',
    'ควบคุมงบประมาณเดือนนี้': 'Monthly budget',
    'ใช้จ่ายจริงเดือนนี้:': 'Spent this month:',
    'งบตั้งไว้:': 'Budget:',
    'ตั้งงบประมาณรายเดือน': 'Set monthly budget',
    'รายการจ่ายประจำ': 'Recurring expenses',
    'เพิ่มรายการจ่ายประจำ': 'Add recurring expense',
    'เพิ่ม': 'Add',
    'ไม่มีรายการจ่ายประจำ': 'No recurring expenses',
    'ลงบันทึกจ่ายแล้ว': 'Record as paid',
    'ลบกระเป๋า': 'Remove wallet',
    'ไม่มี': 'None',
    'อัปโหลดสลิปเพื่อบันทึกบัญชี': 'Scan a slip to record a transaction',
    'ประวัติรายการบัญชี (กดเพื่อแก้ไข/ลบ)':
        'Transaction history (tap to edit or delete)',
    'ยังไม่มีรายการสลิป': 'No transactions yet',
    'สรุปงบกำไร - ขาดทุน สุทธิ': 'Net profit',
    'รายรับรวม': 'Total income',
    'รายจ่ายรวม': 'Total expenses',
    'วันนี้ยังไม่มีรายการที่ยืนยัน เริ่มจดรายการเพื่อให้เห็นกระแสเงินสดครบขึ้น': 'No confirmed transactions today. Record one to keep your cash-flow picture complete.',
    'ผู้ช่วยบันทึกการเงิน': 'Finance logging assistant',
    'ผู้ช่วยบัญชีรายบุคคล': 'Personal finance assistant',
    'ภาพรวมเงินส่วนตัว': 'Personal cash overview',
    'ยอดกระเป๋าที่บันทึกไว้': 'Recorded wallet balance',
    'ยอดจากบัญชีที่กรอกเอง ไม่ใช่ยอดธนาคารแบบเรียลไทม์':
        'Manually entered balance, not a live bank balance',
    'รับเดือนนี้': 'Income this month',
    'จ่ายเดือนนี้': 'Spent this month',
    'คงเหลือ': 'Net',
    'กระแสเงินสดเดือนนี้': 'Cash flow this month',
    'รับ': 'In',
    'จ่าย': 'Out',
    'เงินที่บันทึกไว้อาจรองรับรายจ่ายได้ประมาณ':
        'Recorded funds may cover expenses for about',
    'บันทึกรายจ่ายให้ครบ 3 เดือนเพื่อประเมินเงินสำรอง':
        'Record expenses for three months to estimate your reserve.',
    'เป้าหมายสูงกว่ารายจ่ายเฉลี่ยต่อเดือน ลองปรับเป้าให้สอดคล้องกับรายการจริง': 'This target is above average monthly spending. Adjust it to match your actual transactions.',
    'ช่วงเวลาสรุป': 'Summary period',
    'ช่วงเวลาวิเคราะห์': 'Analysis period',
    'ผลประกอบการในช่วงที่เลือก': 'Results for selected period',
    'เฉลี่ยรายจ่าย': 'Average expenses',
    'ต่อเดือน': 'per month',
    'จำแนกต้นทุนและค่าใช้จ่าย': 'Expense breakdown',
    'จำแนกแหล่งรายรับ': 'Income sources',
    'แนวทางจัดการธุรกิจ': 'Business insights',
    'จำลองแผนลดค่าใช้จ่าย': 'Expense-saving plan',
    'ทดลองแผนธุรกิจ': 'Business simulator',
    'ลองปรับตัวเลขเพื่อดูจุดคุ้มทุนและกำไรโดยประมาณ':
        'Adjust the inputs to estimate break-even and profit.',
    'สถานการณ์จำลอง': 'Scenario',
    'ตามแผน': 'Base plan',
    'ยอดขายลดลง 20%': 'Sales decrease by 20%',
    'ต้นทุนต่อชิ้นเพิ่ม 15%': 'Unit cost increases by 15%',
    'ราคาขายต่อชิ้น': 'Selling price per unit',
    'ต้นทุนต่อชิ้น': 'Variable cost per unit',
    'ค่าใช้จ่ายประจำต่อเดือน': 'Monthly fixed costs',
    'จำนวนขายที่คาดต่อเดือน (ชิ้น)': 'Expected monthly units sold',
    'เงินสดที่มี (ไม่บังคับ)': 'Available cash (optional)',
    'ผลจำลองเป็นค่าประมาณจากตัวเลขที่กรอก ไม่ใช่ยอดบัญชีจริง':
        'Estimate based on your inputs, not actual account balances.',
    'ยังไม่มีรายการที่ยืนยันในช่วงเวลานี้':
        'No confirmed transactions in this period.',
    'รายการที่ต้องตรวจ': 'Needs review',
    'ตรวจและแก้ข้อมูลสลิปก่อนยืนยันลงบัญชี':
        'Review and correct slip details before confirming.',
    'ไม่มีสลิปรอตรวจ': 'No slips need review',
    'รายการที่ต้องตรวจจะปรากฏที่นี่': 'Items needing review will appear here.',
    'ตรวจทานสลิป (Human Confirm)': 'Review slip',
    'ความปลอดภัย': 'Security',
    'ออกจากระบบ': 'Sign out',
    'ส่งออกข้อมูลรายการ': 'Export transactions',
    'บันทึกรายรับและรายจ่ายเป็นไฟล์ CSV':
        'Export income and expenses as a CSV file.',
    'ส่งออกข้อมูลไม่สำเร็จ:': 'Export failed:',
    'ลืมรหัสผ่าน?': 'Forgot password?',
    'อีเมล': 'Email',
    'รหัสผ่าน': 'Password',
    'ชื่อร้านค้า / ผู้ใช้งาน': 'Business or account name',
    'สมัครสมาชิก AI Accounting': 'Create an AI Accounting account',
    'เข้าสู่ระบบ AI Accounting': 'Sign in to AI Accounting',
    'สมัครสมาชิก': 'Create account',
    'เข้าสู่ระบบ': 'Sign in',
    'มีบัญชีแล้ว? เข้าสู่ระบบ': 'Already have an account? Sign in',
    'ยังไม่มีบัญชี? สมัครสมาชิก': 'New here? Create an account',
    'ช่วงเวลาที่ต้องการวางแผน': 'Planning period',
    'ระยะเวลาที่ต้องการวางแผน': 'Planning period',
    'ระยะเวลาวางแผน': 'Planning period',
    'วันที่': 'Date',
    'วันนี้': 'Today',
    'วันจันทร์': 'Monday',
    'วันอาทิตย์': 'Sunday',
    'พ.ศ.': 'Buddhist Era (BE)',
    'ค.ศ.': 'Common Era (CE)',
    'ธีมสว่าง': 'Light theme',
    'ธีมมืด': 'Dark theme',
    'ภาษา': 'Language',
    'ภาษาไทย': 'Thai',
    'อังกฤษ': 'English',
    'บัญชีและข้อมูล': 'Account and data',
    'การแสดงผล': 'Display',
    'ตั้งค่าปฏิทิน': 'Calendar settings',
    'จัดการหมวดหมู่': 'Manage categories',
    'เพิ่มหมวดหมู่': 'Add category',
    'แก้ไขหมวดหมู่': 'Edit category',
    'ผู้ใช้บัญชี': 'Account profile',
    'แก้ไขข้อมูลผู้ใช้': 'Edit profile',
    'ชื่อผู้ใช้': 'Display name',
    'ลบบัญชี': 'Delete account',
    'ยืนยันลบบัญชี': 'Delete account permanently?',
    'เลือกวันเกิด': 'Select date of birth',
    'สมัครสมาชิกได้เมื่ออายุครบ 18 ปีบริบูรณ์':
        'You must be at least 18 years old to register.',
    'วันเดือนปีเกิด': 'Date of birth',
    'เลือกวันเกิด (ต้องมีอายุ 18 ปีขึ้นไป)':
        'Select your date of birth (must be 18 or older)',
    'เกิดข้อผิดพลาด': 'Error',
    'บันทึกข้อมูลผู้ใช้แล้ว': 'Profile saved',
    'บันทึกไม่สำเร็จ': 'Save failed',
    'แก้ชื่อ เพิ่ม หรือลบแท็กที่ใช้กับรายการ':
        'Add, rename, or remove transaction tags.',
    'ชื่อหมวดหมู่ใหม่': 'New category name',
    'ลบหมวดหมู่': 'Delete category',
    'ต้องมีหมวดหมู่อย่างน้อย 1 รายการ': 'At least one category is required.',
    'บันทึกแท็ก': 'Save tags',
    'เพิ่มหรือแก้แท็กที่ใช้กับรายการ': 'Add or edit transaction tags.',
    'ลบบัญชีถาวร?': 'Permanently delete your account?',
    'ระบบจะลบข้อมูลบัญชีและรายการที่แอปจัดเก็บไว้ การดำเนินการนี้ย้อนกลับไม่ได้': 'Your account and app data will be deleted. This action cannot be undone.',
    'ดำเนินการต่อ': 'Continue',
    'ยืนยันรหัสผ่าน': 'Confirm your password',
    'รหัสผ่านไม่ถูกต้อง': 'Incorrect password',
    'ลบบัญชีไม่สำเร็จ กรุณาเข้าสู่ระบบใหม่แล้วลองอีกครั้ง':
        'Could not delete account. Sign in again and retry.',
    'ลบบัญชีไม่สำเร็จ': 'Account deletion failed',
    'รูปแบบปีที่แสดง': 'Calendar year format',
    'ธีม': 'Theme',
    'มีรายการรอตรวจ': 'Items need review',
    'ตรวจยอดและรายละเอียดสลิปก่อนยืนยันลงบัญชี':
        'Review slip details before confirming.',
    'หมวด': 'Category',
    'AI ที่ปรึกษาการเงินธุรกิจรายย่อย': 'AI small-business finance advisor',
    'บันทึกสลิป': 'Save slip',
    'จุดคุ้มทุนประมาณ': 'Break-even is about',
    'ชิ้น/เดือน': 'units/month',
    'ยอดขาย': 'Sales',
    'กำไรสุทธิตามสถานการณ์นี้:': 'Estimated net profit for this scenario:',
    'เงินสดที่กรอกไว้อาจรองรับค่าใช้จ่ายประจำได้':
        'Entered cash may cover fixed costs for',
    'ประมาณ': 'about',
    'วัน': 'days',
    'ยังไม่รวมรายรับใหม่': 'excluding future income',
    'บันทึกข้อมูลกระเป๋าไม่สำเร็จ:': 'Could not save wallet settings:',
    'บันทึกข้อมูลกระเป๋าไม่สำเร็จ': 'Could not save wallet settings',
    'ยังไม่มีกระเป๋าเงิน เพิ่มบัญชีเพื่อเริ่มบันทึกยอด':
        'No wallets yet. Add an account to record its balance.',
    'เตือน: ค่าใช้จ่ายเดือนนี้เกินงบประมาณที่ตั้งไว้แล้ว!':
        'Alert: spending has exceeded this month’s budget.',
    'เตือน: ค่าใช้จ่ายใกล้เต็มงบประมาณแล้ว':
        'Alert: spending is close to the monthly budget.',
    'รอบการจ่าย (เช่น ทุกวันที่ 5)': 'Payment schedule (e.g. every 5th)',
    'ทุกสิ้นเดือน': 'Every month-end',
    'กำหนด': 'Due',
    'บันทึกรายจ่ายไม่สำเร็จ': 'Could not save expense',
    'เงินสุทธิ': 'Net cash flow',
    'อัตรากำไรสุทธิ': 'Net margin',
    'กระแสเงินสดรายเดือน': 'Monthly cash flow',
    'เปรียบเทียบช่วงก่อนหน้า': 'Compare with previous period',
    'รายจ่ายเทียบช่วงก่อนหน้า': 'Expenses vs previous period',
    'ยังไม่มีข้อมูลช่วงก่อนหน้าให้เปรียบเทียบ':
        'No previous period data to compare.',
    'เพิ่มขึ้น': 'increased',
    'ลดลง': 'decreased',
    'เงินสุทธิช่วงนี้': 'Net cash flow this period',
    'แจกแจงรายจ่ายตามหมวด': 'Expenses by category',
    'ยังไม่มีรายการรายจ่ายที่ยืนยันแล้วในช่วงนี้':
        'No confirmed expenses in this period.',
    'คำแนะนำจากรายการจริง': 'Insights from recorded transactions',
    'ทดลองวางแผนจากจำนวนเงิน': 'Try a saving plan',
    'ตั้งเป้าลดรายจ่ายต่อเดือน (บาท)': 'Monthly expense reduction target (THB)',
    'ต้นทุนต่อชิ้นสูงกว่าราคาขาย ยังหาจุดคุ้มทุนไม่ได้':
        'Unit cost exceeds the selling price. Break-even cannot be reached.',
    'ข้อมูลครบช่วยให้คำแนะนำและรายงานแม่นขึ้น':
        'Complete data improves insights and reports.',
  };
}
