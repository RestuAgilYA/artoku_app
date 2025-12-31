import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kebijakan Privasi")),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Kebijakan Privasi ArtoKu",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text("Terakhir diperbarui: 27 Des 2025"),
            SizedBox(height: 20),

            Text(
              "1. Pengumpulan Data",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "Kami mengumpulkan data berupa email (untuk login), foto profil, dan data transaksi keuangan yang Anda masukkan secara manual atau melalui fitur scan.",
            ),

            SizedBox(height: 15),
            Text(
              "2. Penggunaan Kamera & Mikrofon",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "Aplikasi meminta akses kamera untuk memindai struk belanja dan mikrofon untuk fitur input suara. Data ini diproses menggunakan AI dan tidak disebarluaskan.",
            ),

            SizedBox(height: 15),
            Text(
              "3. Keamanan Data",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "Data Anda disimpan secara aman di server kami. Kami tidak menjual data pribadi Anda kepada pihak ketiga.",
            ),

            SizedBox(height: 15),
            Text("4. Kontak", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Jika ada pertanyaan, hubungi kami di restuagil.ya@gmail.com"),
          ],
        ),
      ),
    );
  }
}
