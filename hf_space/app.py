"""API อ่านสลิปสำหรับแอป Flutter (รันบน Hugging Face Space แบบ Docker)

POST /read-slip   (multipart, ฟิลด์ "file" = รูปสลิป)  ->  JSON ยอด/ชื่อ/ธง
GET  /health      ->  สถานะว่าโหลดโมเดลเสร็จหรือยัง

Space เป็น private: แอปต้องส่ง header  Authorization: Bearer <HF token ที่อ่าน Space นี้ได้>
"""
import os
import threading
from pathlib import Path

from fastapi import FastAPI, File, HTTPException, UploadFile

import slip_pipeline

MODEL_DIR = Path(os.environ.get("MODEL_DIR", "models"))
MODEL_REPO = os.environ.get("MODEL_REPO", "")          # private model repo บน HF ที่เก็บ detector/ และ thai-trocr-slip/
MAX_BYTES = 10 * 1024 * 1024

app = FastAPI(title="slip-reader")
_state = {"ready": False, "error": None}
_lock = threading.Lock()                                # อ่านทีละใบ (CPU ฟรีมีแค่ 2 core)


def _load():
    try:
        if not any(MODEL_DIR.rglob("checkpoint_best_total.pth")) if MODEL_DIR.exists() else True:
            if not MODEL_REPO:
                raise RuntimeError("ไม่พบโมเดลใน %s และไม่ได้ตั้ง MODEL_REPO" % MODEL_DIR)
            from huggingface_hub import snapshot_download
            snapshot_download(MODEL_REPO, local_dir=str(MODEL_DIR), token=os.environ.get("HF_TOKEN"))
        slip_pipeline.load_models(MODEL_DIR)
        _state["ready"] = True
    except Exception as err:                            # แสดงใน /health แทนการล้มเงียบ (พร้อมชื่อไฟล์ที่หาไม่เจอ + ไฟล์ที่มีจริง)
        found = sorted(str(p.relative_to(MODEL_DIR)) for p in MODEL_DIR.rglob("*") if p.is_file())[:40] if MODEL_DIR.exists() else []
        _state["error"] = "%s: %s | ไฟล์ใน %s: %s" % (type(err).__name__, err, MODEL_DIR, found)


@app.on_event("startup")
def startup():
    threading.Thread(target=_load, daemon=True).start()  # โหลดเบื้องหลัง ให้ /health ตอบได้ระหว่างรอ


@app.get("/health")
def health():
    return {"ready": _state["ready"], "error": _state["error"], "device": slip_pipeline._dev}


@app.post("/read-slip")
async def read_slip(file: UploadFile = File(...)):
    if not _state["ready"]:
        raise HTTPException(503, _state["error"] or "กำลังโหลดโมเดล ลองใหม่อีกครั้ง")
    data = await file.read()
    if not data or len(data) > MAX_BYTES:
        raise HTTPException(400, "ไฟล์ว่างหรือใหญ่เกิน 10 MB")
    with _lock:
        try:
            return slip_pipeline.read_slip_bytes(data)
        except Exception as err:
            raise HTTPException(500, "อ่านสลิปไม่สำเร็จ: %s" % repr(err)[:200])
