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
                // ignore: deprecated_member_use
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
              "Kami mengumpulkan data minimal berupa email, nama profil, foto opsional, dan seluruh catatan transaksi (termasuk dompet, tabungan, utang/piutang, patungan, dan cicilan). Data ini disinkronkan ke server cloud untuk fungsionalitas aplikasi di berbagai perangkat Anda.",
            ),
            _buildSection(
              "2. Izin Perangkat",
              "• Kamera: Pemindaian struk belanja AI.\n• Mikrofon: Pencatatan suara otomatis.\n• Notifikasi: Pengingat laporan harian.\n• Penyimpanan: Penyimpanan file ekspor laporan (PDF/CSV).\n• Biometrik: Kunci keamanan aplikasi lokal (App Lock).",
            ),
            _buildSection(
              "3. Analisis UX & Perekaman Layar",
              "Untuk meningkatkan pengalaman dan menemukan bug, kami menggunakan Microsoft Clarity. Layanan ini merekam interaksi layar (session replay) secara anonim. Informasi sangat sensitif seperti email, password, dan nilai saldo akan secara otomatis disensor (masking) dan tidak pernah terekam oleh server Clarity.",
            ),
            _buildSection(
              "4. Keamanan & Penggunaan",
              "Data utama Anda disimpan di infrastruktur Firebase Google yang terenkripsi. Kami tidak membagikan atau menjual data pribadi/finansial Anda kepada pihak ketiga mana pun. Kredensial App Lock (Biometrik/PIN) diproses sepenuhnya secara lokal dan tidak pernah diunggah.",
            ),
            _buildSection(
              "5. Kontak Kami",
              "Jika memiliki pertanyaan mengenai privasi dan keamanan data Anda, silakan hubungi developer di: restuagil.ya@gmail.com",
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
