"""ไปป์ไลน์อ่านสลิป (ย้ายมาจาก notebook slip_live): RF-DETR ตีกรอบ -> EasyOCR + ThaiTrOCR (fine-tune) อ่าน -> กฎทำความสะอาด

ใช้: load_models(model_dir) ครั้งเดียว แล้วเรียก read_slip_bytes(ข้อมูลรูป) คืน dict
model_dir ต้องมี  detector/checkpoint_best_total.pth, detector/id2name.json  และ  thai-trocr-slip/ (ไฟล์ save_pretrained)
"""
import difflib
import json
import os
import re
import tempfile
import time
from pathlib import Path

import cv2
import numpy as np
import torch
from PIL import Image

# ---------------- config (ตั้งผ่าน environment ได้) ----------------
CONFIDENCE = int(os.environ.get("CONFIDENCE", 40))          # % ความมั่นใจต่ำสุดของกล่อง
PAD = 6                                                     # เผื่อขอบก่อนตัด (พิกเซล)
USE_TROCR = os.environ.get("USE_TROCR", "1") == "1"         # อ่านชื่อซ้ำด้วย ThaiTrOCR
COMBINE = os.environ.get("COMBINE", "smart")
FULL_FALLBACK = os.environ.get("FULL_FALLBACK", "0") == "1" # อ่านทั้งใบเพื่อหา date/ref_no (ช้าบน CPU)
ROBOFLOW_MODEL = "own-rfdetr-small"                         # ป้ายบันทึกในผลลัพธ์
ALIAS = {"money": "amount", "name": "from_name", "sent": "to_name", "bank": "from_bank", "type payment": "title", "memo": "memo"}
NAME_FIELDS = {"from_name", "to_name"}

det_model = reader = trocr_proc = trocr_model = None
ID2NAME = {}
_dev = "cuda" if torch.cuda.is_available() else "cpu"


def load_models(model_dir):
    # โหลดโมเดลทั้งหมดครั้งเดียวตอนเปิดเซิร์ฟเวอร์
    global det_model, reader, trocr_proc, trocr_model, ID2NAME
    import easyocr
    from rfdetr import RFDETRSmall
    from transformers import TrOCRProcessor, VisionEncoderDecoderModel
    model_dir = Path(model_dir)
    # รองรับทั้งแบบแยกโฟลเดอร์ (detector/, thai-trocr-slip/) และแบบวางไฟล์ทั้งหมดไว้ที่รากของ repo
    weights = next(iter(sorted(model_dir.rglob("checkpoint_best_total.pth"))), None)
    if weights is None:
        raise FileNotFoundError("ไม่พบ checkpoint_best_total.pth ใน %s" % model_dir)
    id2name = weights.parent / "id2name.json"
    if not id2name.exists():
        id2name = next(iter(sorted(model_dir.rglob("id2name.json"))), id2name)
    ID2NAME = {int(k): v for k, v in json.loads(id2name.read_text(encoding="utf-8")).items()}
    det_model = RFDETRSmall(pretrain_weights=str(weights))
    reader = easyocr.Reader(["th", "en"], gpu=torch.cuda.is_available())
    if USE_TROCR:
        st = next(iter(sorted(p for p in model_dir.rglob("model.safetensors") if (p.parent / "config.json").exists())), None)
        if st is None:
            raise FileNotFoundError("ไม่พบ model.safetensors + config.json ของ ThaiTrOCR ใน %s" % model_dir)
        trocr_dir = str(st.parent)
        trocr_proc = TrOCRProcessor.from_pretrained(trocr_dir)
        trocr_model = VisionEncoderDecoderModel.from_pretrained(trocr_dir).to(_dev).eval()


# ======== โค้ดด้านล่างคัดลอกจาก notebook (เซลล์ detect / helpers / ยอดเงิน / read_slip) ========

_cache_miss = []                                  # เซลล์รันหลักยังอ้างตัวแปรนี้ (ตอนนี้ไม่ได้ใช้แคช จึงว่างเสมอ)


def detect(path, conf=None):
    # ตรวจจับกล่องด้วยโมเดลที่เทรนเอง (RF-DETR รันในเครื่อง ไม่เรียก API) คืนรูปแบบเดียวกับที่ Roboflow ให้
    img = cv2.imread(str(path))
    h, w = img.shape[:2]
    det = det_model.predict(Image.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB)), threshold=(conf or CONFIDENCE) / 100)
    preds = [{"class": ID2NAME.get(int(c), str(c)), "confidence": float(s), "x": (b[0] + b[2]) / 2, "y": (b[1] + b[3]) / 2,
              "width": b[2] - b[0], "height": b[3] - b[1]}
             for b, c, s in zip(det.xyxy, det.class_id, det.confidence)]
    return preds, {"width": w, "height": h}


def crop_box(img, p, scale):
    h, w = img.shape[:2]
    cx, cy, bw, bh = p["x"] * scale, p["y"] * scale, p["width"] * scale, p["height"] * scale
    x0 = max(int(cx - bw / 2) - PAD, 0)
    y0 = max(int(cy - bh / 2) - PAD, 0)
    x1 = min(int(cx + bw / 2) + PAD, w)
    y1 = min(int(cy + bh / 2) + PAD, h)
    crop = img[y0:y1, x0:x1]
    if crop.size and crop.shape[0] < 96:           # ช่องเตี้ยเกินไป ขยายให้ OCR อ่านง่าย
        f = 96 / crop.shape[0]
        crop = cv2.resize(crop, None, fx=f, fy=f, interpolation=cv2.INTER_CUBIC)
    return crop


def read_amount(crop):
    # width_ths ต่ำ = แยกเป็นคำ ไม่ให้ป้าย "จำนวน" (ที่ allowlist บังคับให้เป็นเลข) ไปติดกับตัวเลขยอดเงิน
    if crop is None or crop.size == 0:
        return None, None
    rows_d = reader.readtext(crop, detail=1, paragraph=False, allowlist="0123456789.,", width_ths=0.1)
    rows_n = reader.readtext(crop, detail=1, paragraph=False, width_ths=0.1)        # อ่านปกติ (ไม่บังคับเป็นตัวเลข) ไว้เทียบ
    return pick_amount(rows_d), pick_amount(rows_n)


def ocr_text(crop, allowlist=None):
    # อ่านทุกบรรทัดในกรอบ เรียงจากบนลงล่าง แล้วต่อด้วยช่องว่าง
    if crop is None or crop.size == 0:
        return ""
    rows = reader.readtext(crop, detail=1, paragraph=False, allowlist=allowlist)
    items = []
    for box, text, _conf in rows:
        ys = [pt[1] for pt in box]
        xs = [pt[0] for pt in box]
        if text.strip():
            items.append({"yc": sum(ys) / 4, "h": max(ys) - min(ys), "x": min(xs), "t": text.strip()})
    items.sort(key=lambda i: i["yc"])
    lines = []                                   # จัดกลุ่มเป็นบรรทัดก่อน (กล่องที่อยู่แนวเดียวกัน) แล้วค่อยเรียงซ้าย->ขวา
    for it in items:
        if lines and abs(it["yc"] - lines[-1][0]["yc"]) < 0.6 * max(it["h"], lines[-1][0]["h"]):
            lines[-1].append(it)
        else:
            lines.append([it])
    return " ".join(" ".join(i["t"] for i in sorted(line, key=lambda i: i["x"])) for line in lines)


LABEL_TOKEN = re.compile(r"^(?:จาก|ไปยัง|ถึง|from|to)$", re.I)
MASK_OR_NUM = re.compile(r"^(?:[xX*]+[xX*0-9\-]*|[0-9๐-๙][0-9๐-๙\-,.]*)$")     # เลขบัญชีที่ปิดบัง / ตัวเลขล้วน
_trocr_errors = []


def name_line_image(crop):
    # ThaiTrOCR อ่านได้ทีละบรรทัด: ใช้ EasyOCR หา "บรรทัดชื่อ" (ข้ามป้ายจาก/ไปยัง/ถึง และเลขบัญชี) แล้วตัดภาพเฉพาะบรรทัดนั้น
    rows = reader.readtext(crop, detail=1, paragraph=False)
    items = []
    for box, text, _conf in rows:
        t = text.strip()
        if not t or LABEL_TOKEN.match(t) or MASK_OR_NUM.match(t):
            continue
        ys = [pt[1] for pt in box]
        xs = [pt[0] for pt in box]
        items.append({"yc": sum(ys) / 4, "h": max(ys) - min(ys), "x0": min(xs), "y0": min(ys), "y1": max(ys), "t": t})
    items.sort(key=lambda i: i["yc"])
    lines = []
    for it in items:
        if lines and abs(it["yc"] - lines[-1][0]["yc"]) < 0.6 * max(it["h"], lines[-1][0]["h"]):
            lines[-1].append(it)
        else:
            lines.append([it])
    for line in lines:                                           # บรรทัดแรกที่มีตัวอักษรไทย/อังกฤษอย่างน้อย 2 ตัว
        if len(re.findall(r"[A-Za-z\u0e00-\u0e7f]", " ".join(i["t"] for i in line))) >= 2:
            h, w = crop.shape[:2]
            y0 = max(int(min(i["y0"] for i in line)) - 4, 0)
            y1 = min(int(max(i["y1"] for i in line)) + 4, h)
            x0 = max(int(min(i["x0"] for i in line)) - 6, 0)
            return crop[y0:y1, x0:w]                             # ไปจนสุดขอบขวา กันคำที่ EasyOCR ตกหล่น
    return crop


def read_name_trocr(crop):
    # คืนข้อความจาก ThaiTrOCR (สตริงว่างถ้าผิดพลาด เก็บข้อผิดพลาดไว้ใน _trocr_errors)
    if not USE_TROCR or crop is None or crop.size == 0:
        return ""
    try:
        line = name_line_image(crop)
        pil = Image.fromarray(cv2.cvtColor(line, cv2.COLOR_BGR2RGB))
        with torch.no_grad():
            px = trocr_proc(images=pil, return_tensors="pt").pixel_values.to(_dev)
            ids = trocr_model.generate(px, max_length=64)
        return trocr_proc.batch_decode(ids, skip_special_tokens=True)[0].strip()
    except Exception as err:
        _trocr_errors.append(repr(err)[:200])
        return ""


THAI_DIGITS = str.maketrans("๐๑๒๓๔๕๖๗๘๙", "0123456789")
MONEY_RE = r"\d[\d,]*[.,]\d{2}(?!\d)"          # ตัวเลขที่ลงท้ายทศนิยม 2 ตำแหน่ง


def pick_amount(rows):
    # rows = ผล readtext (box, text, conf) ที่แยกเป็นคำแล้ว: เลือกคำที่เป็นยอดเงินจริง (มีทศนิยม 2 ตำแหน่ง)
    # ถ้ามีหลายคำ (เช่น ยอดใหญ่ กับ "0.00 ค่าธรรมเนียม") เลือกตัวที่ตัวอักษรสูงสุด ถ้าเท่ากันเลือกตัวที่อยู่ขวาสุด
    hits = []
    for box, text, _conf in rows:
        t = text.strip(" ,").translate(THAI_DIGITS)
        if re.fullmatch(MONEY_RE, t):
            ys = [pt[1] for pt in box]
            xs = [pt[0] for pt in box]
            hits.append((max(ys) - min(ys), max(xs), t))
    return max(hits)[2] if hits else None


STRICT_MONEY = r"(?:\d{1,3}(?:,\d{3})+|\d+)\.\d{2}"   # คอมมาต้องคั่นทีละ 3 หลัก เช่น 1,380.30 (1741,380.30 ไม่ผ่าน)


def choose_amount(digits_txt, normal_txt):
    # เลือกยอดจาก 2 วิธีอ่าน: ใช้ตัวที่รูปแบบถูกต้องก่อน (ตัวเลขล้วนมาก่อน) และติดธงเมื่อสองวิธีให้ค่าต่างกัน/รูปแบบผิด
    cands = [t for t in (digits_txt, normal_txt) if t]
    good = [t for t in cands if re.fullmatch(STRICT_MONEY, t)]
    pick = (good or cands or [None])[0]
    flag = ""
    if len({parse_money(t) for t in good}) > 1:
        flag = "conflict"
    elif cands and not good:
        flag = "invalid_format"
    return pick, flag


def parse_money(text):
    text = (text or "").translate(THAI_DIGITS)
    m = re.findall(MONEY_RE, text)
    if m:
        whole, dec = re.split(r"[.,](?=\d{2}$)", m[-1])
        return float(whole.replace(",", "").replace(".", "") + "." + dec)
    digits = re.sub(r"[^0-9]", "", text)
    return float(digits) if digits else None


import difflib

PREFIX = r"(?:นาย|นางสาว|นาง|น\.ส\.|ด\.ช\.|ด\.ญ\.)"
MASK_FIX = True          # สลิปที่ปิดนามสกุลเหลือ "แ." (SCB ชุดนี้): OCR อ่านเป็น l. / ii. / ศ. / โ. -> แก้กลับเป็น "แ." (เป็นกฎเฉพาะข้อมูลชุดนี้ ปิดได้)


def clean_name(text):
    s = (text or "").replace("ฺ", "")   # พินทุ ฺ ที่ OCR ใส่เกินมา (เช่น "ฺป")
    s = re.sub(r"([\u0e48-\u0e4b])\1+", r"\1", s.replace("\u0e4d\u0e32", "\u0e33")) 
    s = re.sub(r"\s*\(\s*\d+\s*\)\s*$", "", s)                          # รหัสท้ายชื่อ (24376)
    s = re.sub(r"^[.\s]+", "", s)                                      # จุดนำหน้าที่ OCR เติม เช่น ". teeraphat"
    s = re.sub(r"^(?:จาก|ลาก|ไปยัง|ถึง|from|to)\s*[:：]?\s+", "", s.strip(), flags=re.I)   # ป้ายนำหน้า ("ลาก" = "จาก" ที่ OCR อ่านผิด)
    s = re.sub(r"(?:(?<=\s)|^)(?:จาก|ไปยัง|ถึง)(?=\s|$)", " ", s)             # ป้ายที่ OCR วางไว้กลาง/ท้ายข้อความ (กรอบทั้งแถวของ SCB)
    s = re.sub(r"(?:(?<=\s)|^)[xX*]+[xX*0-9\-]*(?=\s|$)", " ", s)            # เลขบัญชีที่ปิดบัง เช่น xxx-xxx905-1, x-9660
    s = re.sub(r"\s+", " ", s).strip()
    s = re.sub(r"\s+[,;|]+\s*", " ", s).strip()                          # เครื่องหมายลอยที่ OCR เติมเกิน เช่น "วัดจันทาราม ,(เงิน...)" (ไม่แตะ "CO.,LTD.")
    # ตัดตั้งแต่คำบอกชนิดเลข (เลขบัญชี/ผู้เสียภาษี/biller id/รหัสร้านค้า) หรือเลขยาว 6 หลักขึ้นไปเป็นต้นไป
    s = re.sub(r"(?:(?<=\s)|^)(?:เลขประจำตัว|เลขที่|หมายเลข|เลขบัญชี|เลขอ้างอิง|รหัสอ้างอิง|รหัสร้านค้า|รหัสร้าน|biller|ร้านค้า|merchant id)\S*.*$|(?:(?<=\s)|^)[0-9๐-๙][0-9๐-๙\-]{5,}.*$", "", s, flags=re.I).strip()
    m = re.fullmatch(r"(.+?)\s+(%s)" % PREFIX, s)                     # คำนำหน้ามาอยู่ท้ายชื่อ -> ย้ายไปไว้หน้า
    if m:
        s = "%s %s" % (m.group(2), m.group(1))
    if MASK_FIX:
        s = re.sub(r"^(.*\S)\s+(?:l|ll|i|ii|I|II|\||ศ|โ)\.?$", r"\1 แ.", s)
    return s or None


def _norm_name(s):
    s = re.sub(r"^(?:นางสาว|นาง|นาย|น\.ส\.|mr\.?|mrs\.?|ms\.?)\s*", "", (s or "").replace("...", "").strip(), flags=re.I)
    return re.sub(r"[\s.*]", "", s).lower()


def _is_latin(s):
    s = s or ""
    return len(re.findall(r"[A-Za-z]", s)) > len(re.findall(r"[\u0e00-\u0e7f]", s))


def combine_names(easy, trocr, field=None):
    # รวมผลชื่อจาก EasyOCR กับ ThaiTrOCR ตาม COMBINE (ทั้งคู่ผ่าน clean_name แล้ว)
    # COMBINE: "smart" | "trocr_first" | "easy_first" | "trocr" | "easy" หรือ dict รายช่อง เช่น {"from_name": "smart", "to_name": "smart"}
    mode = COMBINE.get(field, "smart") if isinstance(COMBINE, dict) else COMBINE
    if mode == "easy":
        return easy
    if mode == "trocr":
        return trocr
    if mode == "smart":
        if not easy or not trocr:
            return easy or trocr
        if "ฯ" in trocr:
            return easy                                   # TrOCR ตัดข้อความยาวเป็น "ฯลฯ"
        if difflib.SequenceMatcher(None, _norm_name(easy), _norm_name(trocr)).ratio() < 0.35:
            return easy                                   # สองตัวแทบไม่เหมือนกัน = TrOCR อาจแต่งคำ -> เชื่อ EasyOCR
        return trocr                                      # ThaiTrOCR ที่ fine-tune แล้วอ่านวรรณยุกต์/สระแม่นกว่า -> ใช้เป็นหลัก
    first, second = (trocr, easy) if mode == "trocr_first" else (easy, trocr)
    return first or second


def clean_bank(text):
    s = re.sub(r"\s+", " ", (text or "").strip(" .")).strip()
    m = re.fullmatch(r"(.+?)\s+ธ", s)                                   # "กสิกรไทย ธ." -> "ธ.กสิกรไทย"
    if m:
        s = "ธ." + m.group(1).strip(" .")
    return s or None


def extract_date(text):
    t = (text or "").translate(THAI_DIGITS)
    m = re.search(r"(\d{1,2}\s*[ก-ฮ][ก-ฮ.]{1,10}\s*(?:25\d{2}|\d{2}))(?:\s*[-–]?\s*(\d{1,2}:\d{2}))?", t)
    if not m:
        m = re.search(r"(\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4})(?:\s*(\d{1,2}:\d{2}))?", t)
    return " ".join(g for g in (m.group(1), m.group(2)) if g) if m else None


def extract_ref(text):
    m = re.search(r"อ้างอิง\s*[:：]?\s*\(?\s*([A-Za-z0-9]{8,})", text or "")   # กรุงไทยจ่ายบิล: "รหัสอ้างอิง (C2026..."
    if m:
        return m.group(1)
    for tok in re.split(r"\s+", text or ""):                              # ไม่ใช้เลขล้วน กันชนเบอร์โทร
        if re.fullmatch(r"[A-Za-z0-9]{12,}", tok) and re.search(r"[A-Za-z]", tok) and re.search(r"\d", tok):
            return tok
    return None


OCR_DIGITS = str.maketrans({"o": "0", "O": "0", "D": "0", "l": "1", "I": "1", "|": "1", "S": "5", "B": "8"})   # ตัวอักษรที่ OCR สับสนกับตัวเลข
AMOUNT_PADS = (6, 40)                                  # เผื่อขอบซ้าย-ขวา (พิกเซล) อ่าน 2 ขนาด กันเลขหลักหน้าถูกตัด/ติดป้าย "จำนวน"


def _joined_line(rows):
    # ต่อคำในกรอบตามแนวนอน: OCR มักแยก "3" กับ "00" (จุดทศนิยมหาย) หรือ "0." กับ "50" -> ต่อกลับเป็น "3.00" / "0.50"
    items = sorted(rows, key=lambda r: min(pt[0] for pt in r[0]))
    text, boxes = "", []
    for box, t, _c in items:
        t = t.strip().translate(THAI_DIGITS)
        if not t:
            continue
        cur = t.translate(OCR_DIGITS)
        if text and re.fullmatch(r"\d{2}", cur) and re.search(r"\d$", text.translate(OCR_DIGITS)):
            text += "." + t
        elif text and text.endswith("."):
            text += t
        else:
            text += (" " if text else "") + t
        boxes.extend(box)
    return [(boxes, text, None)] if text else []


def money_candidates(rows):
    # ดึงยอดที่รูปแบบถูกต้องจากผล readtext: แก้ o->0, l->1 เฉพาะในก้อนที่เป็นตัวเลข แล้วหา "1,234.56" ในข้อความ
    out = []
    for box, text, _conf in list(rows) + _joined_line(rows):
        for tok in re.findall(r"[\d.,oOlI|SBD]+", text.translate(THAI_DIGITS)):
            tok = tok.translate(OCR_DIGITS).strip(",.")
            if not re.search(r"\d", tok):
                continue
            for m in re.finditer(r"(?<![\d,])" + STRICT_MONEY + r"(?!\d)", tok):
                v = m.group(0)
                if re.match(r"0\d", v):                     # "040.00" = เลขหลักหน้าหาย ไม่เชื่อ
                    continue
                ys = [pt[1] for pt in box]
                out.append((max(ys) - min(ys), v))
    return out


def read_amount_robust(img, p, scale):
    # อ่านยอด 2 ขนาดขอบ x 2 วิธี (ปกติ / ตัวเลขล้วน) แล้วโหวต: คืน (ข้อความยอด, flag)
    votes = {}
    for padx in AMOUNT_PADS:
        h, w = img.shape[:2]
        cx, cy, bw, bh = p["x"] * scale, p["y"] * scale, p["width"] * scale, p["height"] * scale
        x0, x1 = max(int(cx - bw / 2) - padx, 0), min(int(cx + bw / 2) + padx, w)
        y0, y1 = max(int(cy - bh / 2) - PAD, 0), min(int(cy + bh / 2) + PAD, h)
        crop = img[y0:y1, x0:x1]
        if crop.size and crop.shape[0] < 96:
            f = 96 / crop.shape[0]
            crop = cv2.resize(crop, None, fx=f, fy=f, interpolation=cv2.INTER_CUBIC)
        for kw, weight in (({}, 2), ({"allowlist": "0123456789.,"}, 1)):   # อ่านปกติน่าเชื่อกว่า (ตัวเลขล้วนชอบรวมป้าย "จำนวน" เป็นเลข)
            rows = reader.readtext(crop, detail=1, paragraph=False, width_ths=0.1, **kw)
            cands = money_candidates(rows)
            if cands:
                v = max(cands)[1]                         # ตัวอักษรสูงสุด = ยอดหลัก (ไม่ใช่ค่าธรรมเนียม 0.00)
                key = float(v.replace(",", ""))
                votes[key] = votes.get(key, 0) + weight
    if not votes:
        return None, "no_amount"
    ranked = sorted(votes.items(), key=lambda kv: -kv[1])
    best = ranked[0][0]
    flag = "" if len(ranked) == 1 else ("conflict" if ranked[1][1] >= ranked[0][1] * 0.5 else "minor_conflict")
    return "%.2f" % best, flag


RETRY_CONF = 20          # % ถ้ากล่อง amount/from_name/to_name หายที่ CONFIDENCE ปกติ ให้ลองใหม่ที่ความมั่นใจต่ำนี้ (เติมเฉพาะช่องที่หาย) None = ปิด


def read_slip(path, full_fallback=True):
    img = cv2.imread(str(path))
    if img is None:
        return {"file": Path(path).name, "error": "อ่านไฟล์ไม่ได้"}, {}
    preds, size = detect(path)
    scale = img.shape[1] / size["width"] if size.get("width") else 1.0

    groups = {}
    for p in preds:
        field = ALIAS.get(p["class"], p["class"])
        if field != "silp":                                   # silp = กรอบทั้งใบ ไม่มีข้อความให้อ่าน
            groups.setdefault(field, []).append(p)

    need = {"amount", "from_name", "to_name"}
    missing = need - set(groups)
    retried = []
    if RETRY_CONF and missing:                                # ช่องสำคัญหาย -> ตรวจใหม่ที่ความมั่นใจต่ำ เติมเฉพาะช่องที่หาย
        for p in detect(path, RETRY_CONF)[0]:
            field = ALIAS.get(p["class"], p["class"])
            if field in missing:
                groups.setdefault(field, []).append(p)
        retried = sorted(missing & set(groups))

    texts, crops = {}, {}
    amount_flag, amount_alt = "", None
    for field, boxes in groups.items():
        if field in NAME_FIELDS and field not in retried:     # ชื่อ (ปกติ): ลองกล่องที่กว้างกว่าสูงก่อน / ช่องที่ตรวจซ้ำ: เรียงตามความมั่นใจ
            boxes = sorted(boxes, key=lambda b: -b["width"] / max(b["height"], 1))
        else:
            boxes = sorted(boxes, key=lambda b: -b["confidence"])
        for p in boxes[:3]:
            crop = crop_box(img, p, scale)
            if field == "amount":
                text, amount_flag = read_amount_robust(img, p, scale)
                amount_alt = None
                text = text or ""
                             # ไม่เจอคำที่เป็นยอดเงิน -> ถอยไปอ่านข้อความปกติ
            else:
                text = ocr_text(crop)
            if len(text.strip()) >= 2:
                texts[field], crops[field] = text, crop
                break

    # ไม่มีกล่องวันที่/รหัสอ้างอิง: ลองหาจากกล่อง type payment ก่อน แล้วค่อยอ่านทั้งใบ
    blob = " ".join(texts.get(k, "") for k in ("title", "amount"))
    date, ref = extract_date(blob), extract_ref(blob)
    if full_fallback and not (date and ref):
        whole = ocr_text(img)
        date, ref = date or extract_date(whole), ref or extract_ref(whole)

    names = {}                                                    # (EasyOCR, ThaiTrOCR, ผลรวม) ของแต่ละช่องชื่อ
    for f in ("from_name", "to_name"):
        easy = clean_name(texts.get(f))
        tro = clean_name(read_name_trocr(crops.get(f))) if USE_TROCR else None
        names[f] = (easy, tro, combine_names(easy, tro, f))

    row = {
        "file": Path(path).name,
        "folder": Path(path).parent.name,
        "amount": parse_money(texts.get("amount")),
        "amount_raw": texts.get("amount"),
        "amount_alt": amount_alt,                     # ผลจากอีกวิธีอ่าน ไว้เทียบ
        "amount_flag": amount_flag,                   # conflict = สองวิธีอ่านไม่ตรงกัน / invalid_format = รูปแบบผิด ควรตรวจ
        "from_name": names["from_name"][2],
        "from_name_easy": names["from_name"][0],      # ผล EasyOCR ล้วน ไว้เทียบ
        "from_name_trocr": names["from_name"][1],     # ผล ThaiTrOCR ล้วน
        "to_name": names["to_name"][2],
        "to_name_easy": names["to_name"][0],
        "to_name_trocr": names["to_name"][1],
        "bank": clean_bank(texts.get("from_bank")),
        "title": texts.get("title"),
        "memo": texts.get("memo"),
        "date": date,
        "ref_no": ref,
        "found": ",".join(sorted(groups)),
        "retry": ",".join(retried),                   # ช่องที่มาจากการตรวจซ้ำที่ความมั่นใจต่ำ (ควรเช็กรูปพวกนี้)
        "model": ROBOFLOW_MODEL,                      # บันทึกค่าที่ใช้รัน จะได้เทียบรอบต่อรอบได้
        "conf": CONFIDENCE,
    }
    return row, crops


MASK_FIX = False          # ใช้งานจริง: ปิดกฎเฉพาะสลิปชุดเทรน (ไม่งั้นชื่อที่ลงท้ายตัวเดียวจะถูกเปลี่ยนเป็น "แ.")


def read_slip_bytes(data):
    # รับไฟล์รูป (bytes) คืนผลอ่านเป็น dict (แปลงค่าให้ส่งเป็น JSON ได้)
    t0 = time.time()
    suffix = ".png" if data[1:4] == b"PNG" else ".jpg"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as f:
        f.write(data)
        path = f.name
    try:
        row, _crops = read_slip(path, full_fallback=FULL_FALLBACK)
    finally:
        os.unlink(path)
    row.pop("file", None)
    row.pop("folder", None)
    row["seconds"] = round(time.time() - t0, 2)
    return {k: (None if isinstance(v, float) and np.isnan(v) else v) for k, v in row.items()}
