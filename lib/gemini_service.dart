import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:artoku_app/services/logger_service.dart';

class GeminiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _modelName =
      'gemini-2.5-flash'; // Flash lebih cepat dan hemat

  // 1. SCAN STRUK
  static Future<Map<String, dynamic>?> scanReceipt(File imageFile) async {
    if (_apiKey.isEmpty) {
      LoggerService.error("API Key Kosong! Cek .env");
      return null;
    }

    try {
      LoggerService.info("Mengirim gambar struk ke Gemini...");
      final model = GenerativeModel(model: _modelName, apiKey: _apiKey);
      final imageBytes = await imageFile.readAsBytes();

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

      final response = await model.generateContent([
        Content.multi([prompt, DataPart('image/jpeg', imageBytes)]),
      ]);

      LoggerService.info("Gemini Receipt Raw Response: ${response.text}");
      return _cleanAndParseJson(response.text);
    } catch (e, stack) {
      LoggerService.error("Gemini Scan Error", e, stack);
      return null;
    }
  }

  // 2. ANALISA SUARA/TEKS
  static Future<Map<String, dynamic>?> analyzeText(String text) async {
    if (_apiKey.isEmpty) {
      LoggerService.error("API Key Kosong.");
      return null;
    }

    try {
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

      final response = await model.generateContent([Content.text(prompt)]);

      LoggerService.info("Gemini Text Raw Response: ${response.text}");
      return _cleanAndParseJson(response.text);
    } catch (e, stack) {
      LoggerService.error("Gemini Text Analysis Error", e, stack);
      return null;
    }
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
