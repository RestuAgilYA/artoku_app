import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:artoku_app/core/services/gemini_service.dart';
import 'package:artoku_app/core/services/logger_service.dart';
import 'package:artoku_app/core/services/ui_helper.dart';
import 'package:artoku_app/features/transaction/presentation/add_transaction_sheet.dart';

class AiTransactionHelper {
  // --- FUNGSI UNTUK TOMBOL MIC (POPUP SUARA) ---
  // async untuk menunggu hasil dari popup
  static Future<void> showVoiceInput(BuildContext context) async {
    // 1. Buka Popup dan tunggu sampai user menekan 'Selesai' atau 'Batal'
    final String? recordedText = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _VoiceInputPopup(),
    );

    // 2. Jika ada teks yang dikembalikan (User klik Selesai)
    if (recordedText != null && recordedText.isNotEmpty) {
      if (context.mounted) {
        _processTextToGemini(context, recordedText);
      }
    }
  }

  // --- LOGIKA PROSES GEMINI ---
  static Future<void> _processTextToGemini(
    BuildContext context,
    String text,
  ) async {
    bool isLoadingShown = false;

    // Tampilkan Loading di Context Dashboard
    UIHelper.showLoading(context);
    isLoadingShown = true;

    // Hit Gemini
    final aiResult = await GeminiService.analyzeText(text);

    // Tutup Loading (Pastikan context masih ada)
    if (isLoadingShown && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      isLoadingShown = false;
    }

    if (aiResult.data != null && context.mounted) {
      // Buka Sheet Transaksi
      _openTransactionSheet(context, aiResult.data);
    } else if (context.mounted) {
      await _handleAiFailure(
        context,
        errorType: aiResult.errorType,
        isImageFlow: false,
        onRetry: () => _processTextToGemini(context, text),
      );
    }
  }

  // --- FUNGSI UNTUK TOMBOL KAMERA (SCAN STRUK) ---
  static Future<void> pickAndScanImage(
    BuildContext context,
    ImageSource source,
  ) async {
    final ImagePicker picker = ImagePicker();
    bool isLoadingShown = false;

    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 50,
      );

      if (image == null) {
        return;
      }

      if (!context.mounted) return;

      UIHelper.showLoading(context);
      isLoadingShown = true;

      final aiResult = await GeminiService.scanReceipt(File(image.path));

      if (isLoadingShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        isLoadingShown = false;
      }

      if (aiResult.data != null && context.mounted) {
        _openTransactionSheet(context, aiResult.data);
      } else if (context.mounted) {
        await _handleAiFailure(
          context,
          errorType: aiResult.errorType,
          isImageFlow: true,
          onRetry: () => pickAndScanImage(context, source),
        );
      }
    } catch (e, stack) {
      if (isLoadingShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      LoggerService.error("Error Pick/Scan Image", e, stack);
      if (context.mounted) {
        UIHelper.showError(
          context,
          "Terjadi kendala saat membuka kamera/galeri. Periksa izin aplikasi lalu coba lagi.",
        );
      }
    }
  }

  static String _buildAiErrorMessage(
    AiServiceErrorType? errorType, {
    required bool isImageFlow,
  }) {
    switch (errorType) {
      case AiServiceErrorType.missingApiKey:
        return "API Key AI belum dikonfigurasi. Cek file .env (GEMINI_API_KEY).";
      case AiServiceErrorType.rateLimited:
        return "Layanan AI sedang mencapai batas permintaan. Coba lagi beberapa saat.";
      case AiServiceErrorType.quotaExceeded:
        return "Kuota penggunaan AI sudah habis. Silakan cek kuota/billing lalu coba lagi.";
      case AiServiceErrorType.invalidApiKey:
        return "API Key AI tidak valid atau tidak punya izin. Periksa GEMINI_API_KEY Anda.";
      case AiServiceErrorType.network:
        return "Koneksi internet bermasalah saat menghubungi AI. Coba lagi.";
      case AiServiceErrorType.invalidAiResponse:
        return isImageFlow
            ? "AI belum bisa membaca struk ini. Coba foto lebih terang dan tidak blur."
            : "AI belum bisa memahami input. Coba kalimat yang lebih jelas.";
      case AiServiceErrorType.unknown:
      case null:
        return isImageFlow
            ? "Terjadi kendala saat menganalisa gambar struk."
            : "Terjadi kendala saat menganalisa input.";
    }
  }

  static Future<void> _handleAiFailure(
    BuildContext context, {
    required AiServiceErrorType? errorType,
    required bool isImageFlow,
    required Future<void> Function()? onRetry,
  }) async {
    final message = _buildAiErrorMessage(errorType, isImageFlow: isImageFlow);

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("Analisa AI Gagal"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'close'),
              child: const Text("Tutup"),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'retry'),
                child: const Text("Coba Lagi"),
              ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'manual'),
              child: const Text("Isi Manual"),
            ),
          ],
        );
      },
    );

    if (!context.mounted) return;

    if (action == 'manual') {
      _openTransactionSheet(context, null);
      return;
    }

    if (action == 'retry' && onRetry != null) {
      await onRetry();
    }
  }

  static void _openTransactionSheet(
    BuildContext context,
    Map<String, dynamic>? data,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddTransactionSheet(transactionData: data),
    );
  }
}

// --- WIDGET POPUP SUARA ---
class _VoiceInputPopup extends StatefulWidget {
  const _VoiceInputPopup();

  @override
  State<_VoiceInputPopup> createState() => _VoiceInputPopupState();
}

class _VoiceInputPopupState extends State<_VoiceInputPopup> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _text = "Ucapkan sesuatu... (contoh: Makan siang 20 ribu)";
  // Menyimpan teks valid terakhir agar tidak hilang saat status berubah jadi 'done'
  String _lastValidText = "";
  double _soundLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        LoggerService.info("Speech Status: $status");
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (val) {
        LoggerService.error('Speech Error: $val');
        if (mounted) {
          setState(() => _text = "Gagal mendengar. Cek izin mikrofon.");
        }
      },
    );

    if (available) {
      _startListening();
    } else {
      if (mounted) setState(() => _text = "Mikrofon tidak tersedia.");
    }
  }

  void _startListening() {
    setState(() {
      _isListening = true;
      _text = "Mendengarkan...";
    });

    _speech.listen(
      onResult: (val) {
        if (mounted) {
          setState(() {
            _text = val.recognizedWords;
            if (_text.isNotEmpty) {
              _lastValidText = _text;
            }
          });
        }
      },
      onSoundLevelChange: (level) {
        if (mounted) setState(() => _soundLevel = level);
      },
      localeId: "id_ID",
      // ignore: deprecated_member_use
      partialResults: true,
      // ignore: deprecated_member_use
      listenMode: stt.ListenMode.dictation,
    );
  }

  void _stopListening() {
    _speech.stop();
    if (mounted) setState(() => _isListening = false);
  }

  void _finishAndSend() {
    _stopListening();
    // Gunakan _lastValidText jika _text kembali ke default atau kosong
    String finalString =
        _text == "Mendengarkan..." || _text.contains("Ucapkan sesuatu")
        ? _lastValidText
        : _text;

    if (finalString.isEmpty || finalString.contains("Ucapkan sesuatu")) {
      // Jangan tutup jika belum ada input, beri info saja
      setState(() => _text = "Belum ada suara terdeteksi, coba lagi.");
      return;
    }

    // Kembalikan teks ke Parent (Dashboard) untuk diproses
    Navigator.pop(context, finalString);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Cth: Beli Nasi Goreng 20k cash",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),

          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: _isListening
                    ? 100 + (_soundLevel * 10).clamp(0, 100)
                    : 100,
                height: _isListening
                    ? 100 + (_soundLevel * 10).clamp(0, 100)
                    : 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // ignore: deprecated_member_use
                  color: Colors.blueAccent.withOpacity(0.2),
                ),
              ),
              GestureDetector(
                onTap: _isListening ? _stopListening : _startListening,
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: _isListening
                      ? Colors.redAccent
                      : Colors.blueAccent,
                  child: Icon(
                    _isListening ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 35,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              _text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                fontStyle: _text.contains("Ucapkan")
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ),

          const SizedBox(height: 30),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _speech.stop();
                    Navigator.pop(context, null); // BATAL: Return null
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "Batalkan",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: _finishAndSend, // Panggil fungsi finish
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "Selesai",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
