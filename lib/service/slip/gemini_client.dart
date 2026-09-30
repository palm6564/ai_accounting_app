// Directory: lib/service/slip/
// File: gemini_client.dart

import 'dart:async';

import 'package:google_generative_ai/google_generative_ai.dart';

import 'ai_types.dart';
import 'retry.dart';
import 'slip_config.dart';

/// เรียก Gemini จริง: ลองใหม่อัตโนมัติเมื่อติด high demand/โควตา แต่ละคำขอระบุรุ่นเอง
class GeminiClient {
  GeminiClient({required this.apiKey, this.sleep});

  final String apiKey;
  final Future<void> Function(Duration)? sleep;

  bool get isConfigured => apiKey.isNotEmpty;

  Future<String?> call(GeminiRequest request) => withRetry<String?>(() async {
    final model = GenerativeModel(
      model: request.model,
      apiKey: apiKey,
      generationConfig: GenerationConfig(temperature: 0.0),
    );
    final image = request.image;
    final content = image == null
        ? <Content>[Content.text(request.prompt)]
        : <Content>[
            Content.multi(<Part>[
              TextPart(request.prompt),
              DataPart(request.mimeType ?? 'image/jpeg', image),
            ]),
          ];
    final response = await model
        .generateContent(content)
        .timeout(SlipConfig.aiTimeout);
    return response.text;
  }, sleep: sleep);
}
