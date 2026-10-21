// Directory: lib/service/slip/
// File: slip_config.dart

/// ค่าตั้งค่าส่วนอ่านสลิปด้วย AI อ่านจาก --dart-define ทั้งหมด (ห้ามเขียน key ลงในโค้ด)
///
///   flutter run --dart-define-from-file=env.json
class SlipConfig {
  const SlipConfig._();

  // ---- เซิร์ฟเวอร์อ่านสลิปของเราเอง (Hugging Face Space) ตั้งค่าแล้วจะใช้แทน Roboflow ----
  /// เช่น `https://<user>-<space>.hf.space` (ไม่ต้องมี /read-slip)
  static const String slipApiUrl = String.fromEnvironment('SLIP_API_URL');

  /// HF token (read) สำหรับ Space แบบ private ส่งเป็น Authorization: Bearer
  static const String slipApiToken = String.fromEnvironment('SLIP_API_TOKEN');

  /// เวลารอต่อครั้ง (อ่าน 1 ใบบน CPU ราว 5 วินาที แต่ครั้งแรกหลัง Space ตื่นอาจนานกว่า)
  static const Duration slipApiTimeout = Duration(seconds: 90);

  /// Space ที่หลับจะตอบ 503 ระหว่างตื่น/โหลดโมเดล: ลองใหม่ทุก 20 วินาที สูงสุด 10 ครั้ง (~3 นาที)
  static const int slipApiWakeAttempts = 10;
  static const Duration slipApiWakeDelay = Duration(seconds: 20);

  // ---- โมเดลตรวจจับช่องบนสลิปที่เทรนเองบน Roboflow (ตัวสำรอง เมื่อไม่ได้ตั้ง SLIP_API_URL) ----
  static const String roboflowApiKey = String.fromEnvironment(
    'ROBOFLOW_API_KEY',
  );

  /// "ชื่อโปรเจกต์/เลขเวอร์ชัน" เช่น slip-fields/1
  static const String roboflowModel = String.fromEnvironment('ROBOFLOW_MODEL');
  static const double roboflowConfidence = 0.4;

  // ---- key (ตัวเลือกสำรองเดิม ไม่ได้ใช้ในเส้นทางหลักแล้ว) ----
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const String groqApiKey = String.fromEnvironment('GROQ_API_KEY');

  // ---- โมเดล ----
  // อ่านสลิปด้วย 2 รุ่นแล้วเทียบกัน (ค่าเริ่มต้นคือคู่ที่ทดสอบแล้วกับสลิปจริง)
  static const String primaryModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.5-flash-lite',
  );
  static const String checkModel = String.fromEnvironment(
    'GEMINI_FALLBACK_MODEL',
    defaultValue: 'gemini-3.1-flash-lite',
  );
  static const String openAiModel = String.fromEnvironment(
    'OPENAI_MODEL',
    defaultValue: 'gpt-4o-mini',
  );
  static const String groqVisionModel = String.fromEnvironment(
    'GROQ_VISION_MODEL',
    defaultValue: 'meta-llama/llama-4-scout-17b-16e-instruct',
  );

  static const String openAiEndpoint =
      'https://api.openai.com/v1/chat/completions';
  static const String groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  // ---- เกณฑ์คะแนนความมั่นใจ (ค่าเริ่มต้น ยังไม่ได้ปรับจากข้อมูลจำนวนมาก) ----
  /// คะแนนตั้งแต่ค่านี้ = verified
  static const double verifiedScore = 0.85;

  /// ต่ำกว่า verified = pending_review เสมอ ค่านี้ใช้แนะนำในหมายเหตุว่าควรถ่ายใหม่
  static const double retakeScore = 0.5;

  // ---- การเรียก AI ----
  static const int maxAttempts = 4;
  static const Duration aiTimeout = Duration(seconds: 45);
  static const Duration httpTimeout = Duration(seconds: 30);

  /// เว้นระหว่างสลิป (อ่าน 2 รุ่นต่อใบ + จัดหมวด จึงต้องเว้นนานกว่าเดิมกันชนโควตา free tier)
  static const int delayBetweenSlipsMs = int.fromEnvironment(
    'SLIP_DELAY_MS',
    defaultValue: 200,
  );
}
