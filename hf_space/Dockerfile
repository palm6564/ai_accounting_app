FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends libgl1 libglib2.0-0 && rm -rf /var/lib/apt/lists/*

# Space รันด้วย user id 1000
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user PATH=/home/user/.local/bin:$PATH
WORKDIR /home/user/app

# torch แบบ CPU ก่อน (เล็กกว่าแบบ CUDA มาก) แล้วค่อยลงที่เหลือ
COPY --chown=user requirements.txt .
RUN pip install --no-cache-dir --user torch torchvision --index-url https://download.pytorch.org/whl/cpu \
 && pip install --no-cache-dir --user -r requirements.txt

# โหลดโมเดล EasyOCR (th+en) ติดไว้ใน image ตอน build จะได้ไม่ต้องโหลดใหม่ทุกครั้งที่ Space ตื่น
RUN python -c "import easyocr; easyocr.Reader(['th', 'en'], gpu=False)"

COPY --chown=user . .
EXPOSE 7860
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "7860"]
