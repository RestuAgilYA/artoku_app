import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:artoku_app/core/services/logger_service.dart';

enum AiServiceErrorType {
  missingApiKey,
  rateLimited,
  quotaExceeded,
  invalidApiKey,
  network,
  invalidAiResponse,
  unknown,
}

class AiServiceResult {
  final Map<String, dynamic>? data;
  final AiServiceErrorType? errorType;
  final String? rawError;

  AiServiceResult.success(this.data) : errorType = null, rawError = null;

  AiServiceResult.failure(this.errorType, {this.rawError}) : data = null;

  bool get isSuccess => data != null;
}

class GeminiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _modelName =
      'gemini-2.5-flash'; // Flash lebih cepat dan hemat

  static const int _maxRetryCount = 2; // total percobaan = 1 + retry

  // 1. SCAN STRUK
  static Future<AiServiceResult> scanReceipt(File imageFile) async {
    if (_apiKey.isEmpty) {
      LoggerService.error("API Key Kosong! Cek .env");
      return AiServiceResult.failure(AiServiceErrorType.missingApiKey);
    }

    LoggerService.info("Mengirim gambar struk ke Gemini...");

    final model = GenerativeModel(model: _modelName, apiKey: _apiKey);
    final imageBytes = await imageFile.readAsBytes();
    final mimeType = _detectImageMimeType(imageFile.path);

    final prompt = TextPart("""
        Analisa gambar struk ini ke format JSON murni.
        Ambil informasi berikut:
        1. amount: Total pembayaran (integer, tanpa titik/koma).
        2. category: Kategori yang paling cocok ("Makanan", "Transport", "Belanja", "Tagihan", "Hiburan", "Kesehatan", "Lainnya").
        3. note: Nama toko atau item utama secara singkat.
        4. date: Tanggal transaksi (format: YYYY-MM-DD).
        5. wallet: Metode pembayaran yang tertera (contoh: "Cash", "BCA", "Gopay", "OVO", "Mandiri", "Credit Card"). Jika tidak ada info, isi null.

        Contoh Output JSON:
        {"amount": 50000, "category": "Makanan", "note": "Warung Padang", "date": "2023-10-25", "wallet": "Cash"}
      """);

    for (int attempt = 0; attempt <= _maxRetryCount; attempt++) {
      try {
        final response = await model.generateContent([
          Content.multi([prompt, DataPart(mimeType, imageBytes)]),
        ]);

        LoggerService.info("Gemini Receipt Raw Response: ${response.text}");
        final parsed = _cleanAndParseJson(response.text);
        if (parsed == null) {
          return AiServiceResult.failure(
            AiServiceErrorType.invalidAiResponse,
            rawError: response.text,
          );
        }

        return AiServiceResult.success(parsed);
      } catch (e, stack) {
        final errorType = _mapExceptionToErrorType(e);
        final canRetry = _shouldRetry(errorType) && attempt < _maxRetryCount;

        if (canRetry) {
          await _waitBeforeRetry(
            flowName: 'scan struk',
            errorType: errorType,
            attempt: attempt,
          );
          continue;
        }

        LoggerService.error("Gemini Scan Error", e, stack);
        return AiServiceResult.failure(errorType, rawError: e.toString());
      }
    }

    return AiServiceResult.failure(AiServiceErrorType.unknown);
  }

  // 2. ANALISA SUARA/TEKS
  static Future<AiServiceResult> analyzeText(String text) async {
    if (_apiKey.isEmpty) {
      LoggerService.error("API Key Kosong.");
      return AiServiceResult.failure(AiServiceErrorType.missingApiKey);
    }

    LoggerService.info("Mengirim teks ke Gemini: $text");

    final model = GenerativeModel(model: _modelName, apiKey: _apiKey);

    final prompt =
        """
        Anda adalah asisten keuangan pribadi. Analisa kalimat user berikut: "$text".
        Ekstrak informasi ke dalam JSON murni:
        {
          "amount": (integer, konversi kata seperti "50rb" menjadi 50000),
          "type": ("expense" atau "income"),
          "category": (Pilih kategori umum: "Makanan", "Transport", "Belanja", "Tagihan", "Gaji", "Bonus", "Lainnya"),
          "note": (Ringkasan singkat transaksi),
          "wallet": (Metode bayar/sumber dana jika disebut. Contoh: "pakai cash" -> "Cash", "dari gopay" -> "Gopay". Jika tidak disebut, isi null)
        }
      """;

    for (int attempt = 0; attempt <= _maxRetryCount; attempt++) {
      try {
        final response = await model.generateContent([Content.text(prompt)]);

        LoggerService.info("Gemini Text Raw Response: ${response.text}");
        final parsed = _cleanAndParseJson(response.text);
        if (parsed == null) {
          return AiServiceResult.failure(
            AiServiceErrorType.invalidAiResponse,
            rawError: response.text,
          );
        }

        return AiServiceResult.success(parsed);
      } catch (e, stack) {
        final errorType = _mapExceptionToErrorType(e);
        final canRetry = _shouldRetry(errorType) && attempt < _maxRetryCount;

        if (canRetry) {
          await _waitBeforeRetry(
            flowName: 'analisa teks',
            errorType: errorType,
            attempt: attempt,
          );
          continue;
        }

        LoggerService.error("Gemini Text Analysis Error", e, stack);
        return AiServiceResult.failure(errorType, rawError: e.toString());
      }
    }

    return AiServiceResult.failure(AiServiceErrorType.unknown);
  }

  static bool _shouldRetry(AiServiceErrorType errorType) {
    return errorType == AiServiceErrorType.rateLimited ||
        errorType == AiServiceErrorType.network;
  }

  static Future<void> _waitBeforeRetry({
    required String flowName,
    required AiServiceErrorType errorType,
    required int attempt,
  }) async {
    final delaySeconds = 1 << attempt; // 1s, 2s
    LoggerService.warning(
      "Gemini $flowName retry ke-${attempt + 1} dalam $delaySeconds detik (reason: $errorType)",
    );
    await Future.delayed(Duration(seconds: delaySeconds));
  }

  static AiServiceErrorType _mapExceptionToErrorType(Object error) {
    final message = error.toString().toLowerCase();

    if (message.contains('429') ||
        message.contains('rate limit') ||
        message.contains('too many requests') ||
        message.contains('resource_exhausted') ||
        message.contains('unavailable') ||
        message.contains('503')) {
      return AiServiceErrorType.rateLimited;
    }

    if (message.contains('quota') ||
        message.contains('insufficient_quota') ||
        message.contains('billing')) {
      return AiServiceErrorType.quotaExceeded;
    }

    if (message.contains('api key') ||
        message.contains('unauthenticated') ||
        message.contains('permission denied') ||
        message.contains('401') ||
        message.contains('403')) {
      return AiServiceErrorType.invalidApiKey;
    }

    if (message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('timed out') ||
        message.contains('connection') ||
        message.contains('network') ||
        message.contains('timeout')) {
      return AiServiceErrorType.network;
    }

    return AiServiceErrorType.unknown;
  }

  static String _detectImageMimeType(String path) {
    final lowerPath = path.toLowerCase();

    if (lowerPath.endsWith('.png')) return 'image/png';
    if (lowerPath.endsWith('.webp')) return 'image/webp';
    if (lowerPath.endsWith('.gif')) return 'image/gif';
    if (lowerPath.endsWith('.bmp')) return 'image/bmp';

    return 'image/jpeg';
  }

  static Map<String, dynamic>? _cleanAndParseJson(String? text) {
    if (text == null) return null;
    try {
      // Membersihkan markdown ```json ... ```
      String cleanText = text.replaceAll(RegExp(r'```json|```'), '').trim();

      int startIndex = cleanText.indexOf('{');
      int endIndex = cleanText.lastIndexOf('}');
      if (startIndex == -1 || endIndex == -1) return null;

      String jsonString = cleanText.substring(startIndex, endIndex + 1);
      return jsonDecode(jsonString);
    } catch (e) {
      LoggerService.warning("Gagal parsing JSON: $text");
      return null;
    }
  }
}
