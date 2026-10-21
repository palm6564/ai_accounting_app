// Directory: lib/service/slip/
// File: roboflow_detector.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'slip_config.dart';

/// กล่อง 1 กล่องที่โมเดล object detection (เทรนเองบน Roboflow) หาเจอบนสลิป
/// พิกัดเป็นพิกเซลของภาพที่ส่งไป: ([cx], [cy]) คือจุดกึ่งกลางกล่อง
class FieldBox {
  const FieldBox({
    required this.label,
    required this.confidence,
    required this.cx,
    required this.cy,
    required this.width,
    required this.height,
  });

  final String label;
  final double confidence;
  final double cx;
  final double cy;
  final double width;
  final double height;
}

class DetectionResult {
  const DetectionResult({
    required this.boxes,
    required this.imageWidth,
    required this.imageHeight,
  });

  final List<FieldBox> boxes;
  final int imageWidth;
  final int imageHeight;

  /// กล่องที่มั่นใจสุดของแต่ละ class (สลิป 1 ใบมีแต่ละช่องอย่างละ 1)
  Map<String, FieldBox> bestPerLabel() {
    final best = <String, FieldBox>{};
    for (final box in boxes) {
      final current = best[box.label];
      if (current == null || box.confidence > current.confidence) {
        best[box.label] = box;
      }
    }
    return best;
  }
}

/// เรียกโมเดลที่เทรนเองบน Roboflow (Hosted Inference API)
/// ใช้เฉพาะหา "ตำแหน่ง" ของแต่ละช่อง ส่วนการอ่านตัวอักษรทำในเครื่อง (field_ocr.dart)
class RoboflowDetector {
  RoboflowDetector({
    String? apiKey,
    String? model,
    double? confidence,
    http.Client? client,
  }) : apiKey = apiKey ?? SlipConfig.roboflowApiKey,
       model = model ?? SlipConfig.roboflowModel,
       confidence = confidence ?? SlipConfig.roboflowConfidence,
       _client = client ?? http.Client();

  final String apiKey;

  /// รูปแบบ "ชื่อโปรเจกต์/เลขเวอร์ชัน" เช่น slip-fields/1
  final String model;

  /// 0-1
  final double confidence;
  final http.Client _client;

  bool get isConfigured => apiKey.isNotEmpty && model.isNotEmpty;

  Future<DetectionResult> detect(Uint8List image) async {
    final uri = Uri.https('detect.roboflow.com', '/$model', <String, String>{
      'api_key': apiKey,
      'confidence': (confidence * 100).round().toString(),
      'overlap': '30',
    });
    final response = await _client
        .post(
          uri,
          headers: const <String, String>{
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: base64Encode(image),
        )
        .timeout(SlipConfig.httpTimeout);
    if (response.statusCode != 200) {
      final body = response.body;
      throw Exception(
        'Roboflow ${response.statusCode}: '
        '${body.length > 160 ? body.substring(0, 160) : body}',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final size = json['image'] as Map<String, dynamic>? ?? const {};
    final predictions = json['predictions'] as List<dynamic>? ?? const [];
    return DetectionResult(
      imageWidth: (size['width'] as num?)?.toInt() ?? 0,
      imageHeight: (size['height'] as num?)?.toInt() ?? 0,
      boxes: <FieldBox>[
        for (final item in predictions.whereType<Map<String, dynamic>>())
          FieldBox(
            label: item['class'].toString(),
            confidence: (item['confidence'] as num?)?.toDouble() ?? 0,
            cx: (item['x'] as num).toDouble(),
            cy: (item['y'] as num).toDouble(),
            width: (item['width'] as num).toDouble(),
            height: (item['height'] as num).toDouble(),
          ),
      ],
    );
  }
}
