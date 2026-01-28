import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:artoku_app/services/ui_helper.dart'; // Import UIHelper

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final Color primaryColor = const Color(0xFF0F4C5C);
  bool _isLoading = false;

  Future<void> _sendResetLink() async {
    if (_emailController.text.isEmpty) {
      UIHelper.showError(context, "Harap isi email Anda!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      String emailInput = _emailController.text.trim();

      // 1. VALIDASI MANUAL KE FIRESTORE
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: emailInput)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Email tidak terdaftar di sistem.',
        );
      }

      // 2. KIRIM EMAIL
      await FirebaseAuth.instance.sendPasswordResetEmail(email: emailInput);

      if (mounted) {
        UIHelper.showSuccess(
          context,
          "Email Terkirim",
          "Link reset password telah dikirim ke $emailInput.\nCek inbox atau folder spam.",
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "Gagal mengirim email.";
      if (e.code == 'user-not-found') {
        message = "Email tidak terdaftar di ArtoKu.";
      } else if (e.code == 'invalid-email') {
        message = "Format email salah.";
      }

      if (mounted) {
        UIHelper.showError(context, message);
      }
    } catch (e) {
      if (mounted) {
        UIHelper.showError(context, "Terjadi kesalahan sistem: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Deteksi Dark Mode
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;
    // Warna Background Input: Gelap dikit di Dark Mode, Terang di Light Mode
    final Color inputFillColor = isDark
        ? const Color(0xFF2C2C2C)
        : Colors.grey.shade100;
    final Color hintColor = isDark ? Colors.grey.shade500 : Colors.grey;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Forgot Password",
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_reset, size: 80, color: primaryColor),
            ),
            const SizedBox(height: 30),

            Text(
              "Lupa Password Anda?",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Jangan khawatir! Masukkan email yang terdaftar, dan kami akan mengirimkan link untuk mereset password Anda.",
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
            ),
            const SizedBox(height: 40),

            // Input Email (FIXED VISIBILITY)
            Container(
              decoration: BoxDecoration(
                color: inputFillColor, // Warna background dinamis
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),
              child: TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: textColor), // Warna teks input dinamis
                decoration: InputDecoration(
                  hintText: "Alamat Email",
                  hintStyle: TextStyle(color: hintColor),
                  prefixIcon: Icon(Icons.email_outlined, color: hintColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendResetLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Reset Password",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
