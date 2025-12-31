import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Import package ini

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // Fungsi Helper Membuka Link (FIXED)
  Future<void> _launchURL(BuildContext context, String urlString) async {
    final Uri uri = Uri.parse(urlString);
    try {
      // Mode externalApplication agar membuka aplikasi terinstall (LinkedIn/IG)
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $uri';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal membuka link: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color descriptionColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Tentang Pembuat",
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            // ... (Bagian Logo & Nama App Tetap Sama) ...
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/images/icon_ArtoKu.png',
                height: 100,
                width: 100,
                errorBuilder: (ctx, err, _) => const Icon(
                  Icons.account_balance_wallet,
                  size: 80,
                  color: Colors.teal,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "ArtoKu App v1.0.0",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              "Kelola Keuangan Jadi Mudah",
              style: TextStyle(color: descriptionColor),
            ),
            const SizedBox(height: 20),

            // FOTO CREATOR
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0F4C5C), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/profile.jpeg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade300,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            Text(
              "Dibuat oleh:",
              style: TextStyle(fontSize: 14, color: descriptionColor),
            ),
            const SizedBox(height: 5),
            const Text(
              "Restu Agil Yuli Arjun",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F4C5C),
              ),
            ),
            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "ArtoKu dikembangkan untuk memenuhi kebutuhan pencatatan keuangan yang sederhana dan terstruktur. Aplikasi ini membantu pengguna memantau pemasukan dan pengeluaran secara praktis, membangun kebiasaan finansial yang sehat, serta mendukung pengambilan keputusan keuangan yang lebih bijak.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: descriptionColor,
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // --- TAMBAHAN AJAKAN (CALL TO ACTION) ---
            Text(
              "Ingin berdiskusi atau kenalan lebih jauh?",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "Temukan saya di sosial media:",
              style: TextStyle(color: descriptionColor, fontSize: 12),
            ),
            const SizedBox(height: 20),

            // SOCIAL LINKS
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialImage(
                  context,
                  "assets/images/github.png",
                  "GitHub",
                  "https://github.com/RestuAgilYA",
                  isDark,
                ),
                const SizedBox(width: 20),
                _buildSocialImage(
                  context,
                  "assets/images/linkedin.png",
                  "LinkedIn",
                  "https://www.linkedin.com/in/restuagilya/",
                  isDark,
                ),
                const SizedBox(width: 20),
                _buildSocialImage(
                  context,
                  "assets/images/instagram.png",
                  "Instagram",
                  "https://www.instagram.com/_restuagil/",
                  isDark,
                ),
                const SizedBox(width: 20),
                _buildSocialImage(
                  context,
                  "assets/images/gmail_logo.png",
                  "Email",
                  "mailto:restuagil.ya@gmail.com",
                  isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialImage(
    BuildContext context,
    String assetPath,
    String label,
    String url,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => _launchURL(context, url), // Panggil fungsi launch
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Image.asset(
              assetPath,
              width: 30,
              height: 30,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.link, size: 30),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
