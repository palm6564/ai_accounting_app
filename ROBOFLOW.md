# เทรนโมเดลอ่านสลิปบน Roboflow

โปรเจกต์ประเภท **Object Detection** ใช้ class ชุดนี้ (แมปในโค้ดที่ `SlipFields.alias`):

| class ใน Roboflow | ลากกล่องที่ | แอปใช้เป็น |
|---|---|---|
| `money` | ตัวเลขยอดเงิน (รวม "บาท" ได้) | ยอดเงิน |
| `name` | ชื่อผู้โอน (ใต้ "จาก") | ผู้โอน |
| `sent` | ชื่อผู้รับ (ใต้ "ไปยัง") | ผู้รับ |
| `bank` | ชื่อธนาคารใต้ชื่อคน | ธนาคาร |
| `type payment` | ข้อความหัวสลิป เช่น โอนเงินสำเร็จ | เดาประเภทรายการ |
| `silp` | ทั้งใบ | (ไม่ใช้ในแอป) |

วันที่และรหัสอ้างอิงไม่มี class: แอปอ่านทั้งใบด้วย Tesseract แล้วจับด้วย regex
(`extractDate`, `extractRef`) ถ้า OCR อ่านไม่ออก สลิปจะเข้าสถานะรอตรวจ

1. อัปโหลดสลิปจริง 150+ ใบ หลายธนาคาร/หลายมุม แล้ว label ตามตารางข้างบน
2. Generate version → Train → ได้ชื่อ `project/เลขเวอร์ชัน`
3. ใส่ `env.json` (อยู่ใน .gitignore): `ROBOFLOW_API_KEY`, `ROBOFLOW_MODEL`
4. วาง `tha.traineddata`, `eng.traineddata` (tessdata_fast) ใน `assets/tessdata/`
5. `flutter run --dart-define-from-file=env.json`

Flow: ภาพ → Roboflow หาตำแหน่ง → ตัดภาพ → OCR ในเครื่อง → `RoboflowSlipReader.buildRead`
→ `SlipReader.evaluate` ให้คะแนน → verified / pending_review
