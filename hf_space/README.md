---
title: Slip Reader
emoji: 🧾
colorFrom: blue
colorTo: green
sdk: docker
app_port: 7860
pinned: false
---

# Slip Reader API (private)

อ่านสลิปโอนเงิน: RF-DETR (เทรนเอง) ตีกรอบ → EasyOCR + ThaiTrOCR (fine-tune) อ่านยอด/ชื่อ

- `GET /health` → `{"ready": true/false, "error": ..., "device": "cpu"}`
- `POST /read-slip` (multipart, ฟิลด์ `file`) → JSON เช่น
  `{"amount": 25.0, "amount_flag": "", "from_name": "...", "to_name": "...", "memo": null, "date": "...", "ref_no": "...", "retry": "", "seconds": 12.3}`

ทุก request ต้องมี `Authorization: Bearer <HF token>` เพราะ Space เป็น private

## ตั้งค่าใน Settings ของ Space
- Secret `HF_TOKEN`: token (read) ที่อ่าน model repo ได้
- Variable `MODEL_REPO`: ชื่อ model repo ส่วนตัว เช่น `<user>/slip-models` ที่มีโฟลเดอร์
  - `detector/checkpoint_best_total.pth`, `detector/id2name.json`
  - `thai-trocr-slip/` (config.json, model.safetensors, processor_config.json, tokenizer*.json, generation_config.json)

ตัวเลือกเพิ่ม (Variables): `CONFIDENCE` (ค่าเริ่มต้น 40), `USE_TROCR` (1/0), `FULL_FALLBACK` (1 = อ่านทั้งใบหา date/ref_no ช้ากว่า)

`amount_flag` ไม่ว่าง หรือ `retry` มีค่า = ให้ผู้ใช้ตรวจยอด/ชื่อก่อนบันทึก
