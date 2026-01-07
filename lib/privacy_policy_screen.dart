import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Kebijakan Privasi",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF0F4C5C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.privacy_tip,
                    color: Color(0xFF0F4C5C),
                    size: 40,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      "Privasi Anda adalah prioritas utama kami di ArtoKu.",
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            _buildSection(
              "1. Pengumpulan Data",
              "Kami mengumpulkan data minimal berupa email (untuk login), foto profil opsional, dan catatan transaksi keuangan yang Anda masukkan. Data ini digunakan murni untuk fungsionalitas aplikasi.",
            ),
            _buildSection(
              "2. Izin Perangkat",
              "• Kamera: Digunakan hanya saat Anda memindai struk belanja.\n• Mikrofon: Digunakan hanya saat Anda menggunakan fitur input suara.\n• Notifikasi: Untuk pengingat harian.",
            ),
            _buildSection(
              "3. Keamanan",
              "Data Anda disimpan di server cloud terenkripsi (Firebase). Kami tidak membagikan atau menjual data pribadi Anda kepada pihak ketiga manapun.",
            ),
            _buildSection(
              "4. Kontak Kami",
              "Jika memiliki pertanyaan mengenai privasi, silakan hubungi developer di: restuagil.ya@gmail.com",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F4C5C),
            ),
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(height: 1.5, fontSize: 14)),
        ],
      ),
    );
  }
}
