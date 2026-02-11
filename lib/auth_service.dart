import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart'; // Pastikan ini sesuai nama file dashboard kamu
import 'package:artoku_app/services/ui_helper.dart';
import 'package:artoku_app/services/logger_service.dart';

class AuthService {
  static Future<void> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // Batal login

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        final userDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        final docSnapshot = await userDoc.get();

        if (!docSnapshot.exists) {
          await userDoc.set({
            'email': user.email,
            'fullName': user.displayName ?? '',
            'phone': '',
            'createdAt': DateTime.now().toIso8601String(),
          });
        }

        // Simpan info untuk login biometrik dengan Google
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('biometric_login_type', 'google');
        await prefs.setString('biometric_email', user.email ?? '');
        await prefs.remove('biometric_pass'); // Hapus password jika ada

        if (context.mounted) {
          // Ganti snackbar dengan UIHelper agar konsisten
          // Atau karena ini transisi cepat ke Dashboard, boleh skip UIHelper sukses jika dirasa mengganggu
          // Tapi untuk konsistensi error handling:
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
            (route) => false,
          );
        }
      }
    } catch (e, stack) {
      LoggerService.error("Google Sign In Error", e, stack);
      if (context.mounted) {
        UIHelper.showError(
          context,
          "Gagal Login Google. Cek koneksi internet.",
        );
      }
    }
  }
}
