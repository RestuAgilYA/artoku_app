import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart'; // Untuk debugPrint
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  // Mengambil API Key dari .env dengan fallback string kosong
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  // Model yang stabil dan gratis
  static const String _modelName = 'gemini-2.5-flash';

  // 1. FUNGSI SCAN GAMBAR (STRUK)
  static Future<Map<String, dynamic>?> scanReceipt(File imageFile) async {
    if (_apiKey.isEmpty) {
      debugPrint("Error: API Key Gemini belum diset di .env");
      return null;
    }

    try {
      final model = GenerativeModel(model: _modelName, apiKey: _apiKey);
      final imageBytes = await imageFile.readAsBytes();

      final prompt = TextPart("""
        Analisa gambar struk ini ke JSON.
        1. amount: Total bayar (integer).
        2. category: "Makanan", "Transport", "Belanja", "Tagihan", "Hiburan", "Kesehatan", "Lainnya".
        3. note: Nama toko/item.
        4. date: YYYY-MM-DD.
        5. wallet: Metode pembayaran. Cari kata kunci "Cash", "Tunai", "BCA", "Mandiri", "Gopay", "OVO", "Debit", "Credit". 
           Jika tidak ditemukan di struk, isi null.
           Contoh: "Tunai" -> "Cash". "Bank BCA" -> "BCA".

        Output JSON murni:
        {"amount": 0, "category": "Lainnya", "note": "", "date": null, "wallet": null}
      """);

      final imagePart = DataPart('image/jpeg', imageBytes);
      final response = await model.generateContent([
        Content.multi([prompt, imagePart]),
      ]);

      debugPrint("Gemini Receipt Response: ${response.text}");
      return _cleanAndParseJson(response.text);
    } catch (e) {
      debugPrint("Gemini Error (Image): $e");
      return null;
    }
  }

  // 2. FUNGSI ANALISA SUARA (TEKS)
  static Future<Map<String, dynamic>?> analyzeText(String text) async {
    if (_apiKey.isEmpty) {
      debugPrint("Error: API Key Gemini kosong.");
      return null;
    }

    try {
      final model = GenerativeModel(model: _modelName, apiKey: _apiKey);

      final prompt =
          """
        Analisa kalimat transaksi ini: "$text".
        Ekstrak ke JSON murni:
        {
          "amount": (integer, contoh: 50000. Konversi "50rb" jadi 50000),
          "type": ("expense" atau "income"),
          "category": (Pilih: "Makanan", "Transport", "Belanja", "Tagihan", "Gaji", "Bonus", "Lainnya"),
          "note": (Ringkasan singkat),
          "wallet": (Metode bayar jika disebut. Contoh: "pakai cash", "lewat bca", "dari gopay". Jika tidak disebut, isi null)
        }
        
        Contoh User: "Beli bakso 15 ribu pakai cash"
        Output: {"amount": 15000, "type": "expense", "category": "Makanan", "note": "Bakso", "wallet": "Cash"}
      """;

      final response = await model.generateContent([Content.text(prompt)]);

      debugPrint("Gemini Text Response: ${response.text}");
      return _cleanAndParseJson(response.text);
    } catch (e) {
      debugPrint("Gemini Error (Text): $e");
      return null;
    }
  }

  static Map<String, dynamic>? _cleanAndParseJson(String? text) {
    if (text == null) return null;
    try {
      int startIndex = text.indexOf('{');
      int endIndex = text.lastIndexOf('}');
      if (startIndex == -1 || endIndex == -1) return null;
      String cleanJson = text.substring(startIndex, endIndex + 1);
      return jsonDecode(cleanJson);
    } catch (e) {
      debugPrint("Error Parsing JSON Gemini: $e");
      return null;
    }
  }
}
