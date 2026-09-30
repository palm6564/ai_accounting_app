// Directory: lib/service/
// File: api_service.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'slip/compatible_client.dart';
import 'slip/direction_matcher.dart';
import 'slip/gemini_client.dart';
import 'slip/ai_types.dart';
import 'slip/offline_slip_parser.dart';
import 'slip/slip_categorizer.dart';
import 'slip/slip_config.dart';
import 'slip/slip_models.dart';
import 'slip/slip_reader.dart';
import 'slip/slip_text.dart';

class SlipImportSummary {
  final int savedCount;
  final int duplicateCount;
  final int offlineCount;

  final List<String> errors;

  const SlipImportSummary({
    required this.savedCount,
    required this.duplicateCount,
    required this.offlineCount,
    required this.errors,
  });
}

/// ข้อมูลผู้ใช้ที่ใช้ตัดสินเข้า/ออกของสลิป
class _Owner {
  const _Owner(this.name, this.matcher);

  final String name;
  final OwnerMatcher matcher;
}

/// จุดเข้าใช้งานส่วนอ่านสลิปด้วย AI (หน้าตาภายนอกเหมือนเดิมทุกอย่าง)
///
/// ตรรกะจริงอยู่ใน lib/service/slip/ : อ่านภาพด้วย Gemini 2 รุ่นเทียบกัน → ตรวจ/ให้คะแนนด้วยโค้ด →
/// ตัดสินเข้า/ออก/โอนภายในด้วยชื่อและเลขบัญชี → จัดหมวดตามชุดหมวดของสมุดบัญชี
class ApiService {
  static final ImagePicker _picker = ImagePicker();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<List<XFile>> pickMultipleSlips() async {
    return await _picker.pickMultiImage(imageQuality: 85);
  }

  /// [categoryHints] = หมวดที่ผู้ใช้เลือกไว้ก่อนอัปโหลด (ชื่อไฟล์ → หมวด) ถ้าหมวดอยู่ในชุดหมวดของสมุดจะใช้เลย ไม่ให้ AI เดา
  /// [onProgress] = แจ้งความคืบหน้าทีละใบ (ไม่บังคับ)
  static Future<SlipImportSummary> processAndSaveSlips(
    List<XFile> images,
    String userId, {
    String bookletId = 'business',
    Map<String, String>? categoryHints,
    void Function(int done, int total)? onProgress,
  }) async {
    final userRef = _db.collection('users').doc(userId);
    final transactions = userRef.collection('transactions');
    final owner = await _loadOwner(userRef);
    final profile = await _loadProfile(userRef, bookletId);

    final gemini = GeminiClient(apiKey: SlipConfig.geminiApiKey);
    if (!gemini.isConfigured &&
        SlipConfig.openAiApiKey.isEmpty &&
        SlipConfig.groqApiKey.isEmpty) {
      debugPrint(
        '⚠ ยังไม่ได้ตั้ง GEMINI_API_KEY / OPENAI_API_KEY / GROQ_API_KEY '
        '(--dart-define) ทุกสลิปจะใช้ regex ออฟไลน์ ซึ่งอ่านภาษาไทยไม่ได้',
      );
    }
    final GeminiCall geminiCall = gemini.isConfigured
        ? gemini.call
        : (GeminiRequest request) async => null;
    final reader = SlipReader(call: geminiCall, onLog: debugPrint);
    final categorizer = SlipCategorizer(
      profile: profile,
      ask: gemini.isConfigured
          ? (String prompt) => geminiCall(
              GeminiRequest(model: SlipConfig.primaryModel, prompt: prompt),
            )
          : null,
    );

    var savedCount = 0;
    var duplicateCount = 0;
    var offlineCount = 0;
    final errors = <String>[];

    for (var index = 0; index < images.length; index++) {
      final image = images[index];
      try {
        final outcome = await _readOne(
          image,
          owner,
          reader,
          categorizer,
          categoryHints?[image.name],
        );
        if (outcome.isFallback) offlineCount++;

        if (await _isDuplicate(transactions, outcome)) {
          debugPrint('สลิปนี้ถูกบันทึกไปแล้ว (Ref: ${outcome.refNo})');
          duplicateCount++;
        } else {
          await transactions.add(<String, dynamic>{
            ...outcome.toFields(),
            'date': Timestamp.fromDate(outcome.date ?? DateTime.now()),
            'bookletId': bookletId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          savedCount++;
          debugPrint(
            'บันทึกสำเร็จ! ประเภท: ${outcome.type}, จำนวน: ${outcome.amount} บาท '
            '(${outcome.source}, ${outcome.status})',
          );
        }
      } catch (error) {
        debugPrint('เกิดข้อผิดพลาดในการอ่านสลิป: $error');
        errors.add('${image.name}: $error');
      }

      onProgress?.call(index + 1, images.length);
      if (index < images.length - 1) {
        await Future<void>.delayed(
          Duration(milliseconds: SlipConfig.delayBetweenSlipsMs),
        );
      }
    }
    return SlipImportSummary(
      savedCount: savedCount,
      duplicateCount: duplicateCount,
      offlineCount: offlineCount,
      errors: errors,
    );
  }

  // ------------------------------------------------------------ อ่านสลิป 1 ใบ

  /// ลำดับ: Gemini 2 รุ่น → OpenAI/Groq (ถ้าตั้ง key) → regex ออฟไลน์ → รายการเปล่าให้กรอกเอง (ไม่ทิ้งสลิป)
  static Future<SlipOutcome> _readOne(
    XFile image,
    _Owner owner,
    SlipReader reader,
    SlipCategorizer categorizer,
    String? hint,
  ) async {
    final ocrText = await _recognizeSlipText(image);
    final bytes = await image.readAsBytes();
    final mime = _mimeType(image);

    var scored = await reader.read(
      image: bytes,
      mimeType: mime,
      ownerName: owner.name,
      ocrHint: ocrText,
    );
    scored ??= await _readWithOtherProviders(
      reader,
      bytes,
      mime,
      owner.name,
      ocrText,
    );
    if (scored == null) {
      // บอกสาเหตุในหมายเหตุของรายการ ผู้ใช้จะได้เห็นโดยไม่ต้องเปิด log
      final reason = SlipConfig.geminiApiKey.isEmpty
          ? 'ไม่ได้ตั้ง GEMINI_API_KEY (ต้องรันด้วย --dart-define-from-file=env.json แล้วหยุดและรันใหม่ทั้งหมด)'
          : reader.errors.isEmpty
          ? 'ไม่มีรุ่นไหนตอบกลับ'
          : reader.errors.join(' | ');
      debugPrint('AI ทุกตัวใช้ไม่ได้: $reason');
      return ocrText != null
          ? OfflineSlipParser.parse(ocrText, reason: reason)
          : OfflineSlipParser.emergency(reason: reason);
    }

    final read = scored.read;
    final issues = List<String>.of(scored.issues);
    var score = scored.score;

    // เข้า/ออก/โอนภายใน: เทียบชื่อและเลขบัญชีของผู้ใช้ด้วยโค้ด ไม่ให้ AI เดาเอง
    final matched = owner.matcher.detectType(read);
    final type = matched ?? read.typeGuess ?? 'expense';
    if (matched == null) {
      issues.add('ไม่พบบัญชีของผู้ใช้บนสลิป (เข้า/ออกมาจากการเดาของ AI)');
      score = (math.max(0.0, score - 0.2) * 100).round() / 100;
    }

    final decision = await categorizer.categorize(
      read: read,
      type: type,
      hint: hint,
    );
    final status = score >= SlipConfig.verifiedScore
        ? 'verified'
        : 'pending_review';
    final noteLines = <String>[
      if (decision.note.isNotEmpty) decision.note,
      if (read.memo != null) 'บันทึกช่วยจำ: ${read.memo}',
      if (status == 'pending_review' && issues.isNotEmpty)
        'ตรวจ: ${issues.join(', ')}',
    ];
    final title = type == 'internal_transfer'
        ? 'โอนระหว่างบัญชีตัวเอง'
        : type == 'income'
        ? 'รับเงินจาก ${read.fromName ?? 'ไม่ระบุ'}'
        : 'โอนให้ ${read.toName ?? 'ไม่ระบุ'}';

    return SlipOutcome(
      title: title,
      amount: read.amount ?? 0.0,
      type: type,
      category: decision.category,
      note: noteLines.join('\n'),
      confidence: score,
      status: status,
      refNo: read.refNo ?? '',
      refKey: canonRef(read.refNo),
      date: scored.date,
      source: scored.source,
      issues: issues,
    );
  }

  /// ตัวสำรองเมื่อ Gemini ใช้ไม่ได้ทั้งสองรุ่น: ผู้ให้บริการที่ตั้ง key ไว้ (ผลมีรุ่นเดียว จึงถูกหักคะแนนไปรอตรวจ)
  static Future<ScoredRead?> _readWithOtherProviders(
    SlipReader reader,
    Uint8List bytes,
    String mime,
    String ownerName,
    String? ocrText,
  ) async {
    final prompt = SlipReader.buildPrompt(
      ownerName: ownerName,
      ocrHint: ocrText,
    );
    final providers = <List<String>>[
      <String>[
        'openai_${SlipConfig.openAiModel}',
        SlipConfig.openAiApiKey,
        SlipConfig.openAiEndpoint,
        SlipConfig.openAiModel,
      ],
      <String>[
        'groq_${SlipConfig.groqVisionModel}',
        SlipConfig.groqApiKey,
        SlipConfig.groqEndpoint,
        SlipConfig.groqVisionModel,
      ],
    ];
    for (final provider in providers) {
      if (provider[1].isEmpty) continue;
      final text = await callCompatibleModel(
        apiKey: provider[1],
        endpoint: provider[2],
        model: provider[3],
        prompt: prompt,
        image: bytes,
        mimeType: mime,
      );
      final read = text == null
          ? null
          : SlipRead.fromJson(parseJsonObject(text));
      if (read != null)
        return reader.evaluate(<SlipRead>[read], source: provider[0]);
    }
    return null;
  }

  /// OCR ในเครื่อง (ML Kit แบบ latin อ่านภาษาไทยไม่ได้ ใช้เป็นตัวช่วยอ้างอิงและตัวสำรองออฟไลน์เท่านั้น)
  static Future<String?> _recognizeSlipText(XFile image) async {
    if (kIsWeb) return null;

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(image.path),
      );
      final text = recognized.text.trim();
      debugPrint('ML Kit อ่านข้อความได้ ${text.length} ตัวอักษร');
      return text.isEmpty ? null : text;
    } catch (error) {
      debugPrint('ML Kit OCR ล้มเหลว: $error');
      return null;
    } finally {
      await recognizer.close();
    }
  }

  // ------------------------------------------------------------------ Firestore

  /// ชื่อผู้ใช้ (displayName/name) และเลขบัญชี (`myAccounts` ไม่บังคับ) ไว้เทียบกับชื่อบนสลิป
  static Future<_Owner> _loadOwner(
    DocumentReference<Map<String, dynamic>> userRef,
  ) async {
    try {
      final data = (await userRef.get()).data();
      final name = (data?['displayName'] ?? data?['name'] ?? '').toString();
      final accounts = data?['myAccounts'];
      return _Owner(
        name,
        OwnerMatcher(
          names: name.isEmpty ? const <String>[] : <String>[name],
          accounts: accounts is Iterable
              ? accounts.map((item) => item.toString())
              : const <String>[],
        ),
      );
    } catch (error) {
      debugPrint('ดึงข้อมูลโปรไฟล์ผู้ใช้ไม่สำเร็จ: $error');
      return _Owner('', OwnerMatcher());
    }
  }

  /// ชุดหมวดตามสมุดบัญชี ไม่มีการตั้งค่า = ชุดเดิมของแอป
  static Future<CategoryProfile> _loadProfile(
    DocumentReference<Map<String, dynamic>> userRef,
    String bookletId,
  ) async {
    try {
      final doc = await userRef.collection('booklets').doc(bookletId).get();
      return CategoryProfile.fromBookletData(doc.data());
    } catch (error) {
      debugPrint('ดึงข้อมูลสมุดบัญชีไม่สำเร็จ: $error');
      return CategoryProfile.legacy;
    }
  }

  /// ซ้ำถ้ามีเลขอ้างอิงเดียวกัน หรือเลขอ้างอิงแบบมาตรฐานเดียวกัน (I/l/1 และ O/0 ถือเป็นตัวเดียวกัน)
  static Future<bool> _isDuplicate(
    CollectionReference<Map<String, dynamic>> transactions,
    SlipOutcome outcome,
  ) async {
    if (outcome.refNo.isEmpty) return false;
    final exact = await transactions
        .where('refNo', isEqualTo: outcome.refNo)
        .limit(1)
        .get();
    if (exact.docs.isNotEmpty) return true;
    if (outcome.refKey.isEmpty) return false;
    final canonical = await transactions
        .where('refKey', isEqualTo: outcome.refKey)
        .limit(1)
        .get();
    return canonical.docs.isNotEmpty;
  }

  static String _mimeType(XFile image) {
    final mimeType = image.mimeType;
    if (mimeType != null) return mimeType;
    final name = image.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.heic') || name.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }
}
