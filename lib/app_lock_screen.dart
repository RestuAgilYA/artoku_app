import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:artoku_app/services/ui_helper.dart';
import 'package:artoku_app/app_lock_setup_page.dart';
import 'package:artoku_app/forgot_password_screen.dart';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlockSuccess;

  const AppLockScreen({
    super.key,
    required this.onUnlockSuccess,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  String _pinInput = "";
  bool _isLoading = false;
  final int _pinLength = 6;
  final Color primaryColor = const Color(0xFF0F4C5C);

  @override
  void initState() {
    super.initState();
  }

  void _addDigit(String digit) {
    if (_pinInput.length < _pinLength) {
      setState(() {
        _pinInput += digit;
      });
      
      // Auto-check ketika PIN sudah 6 digit
      if (_pinInput.length == _pinLength) {
        _verifyPin();
      }
    }
  }

  void _removeDigit() {
    if (_pinInput.isNotEmpty) {
      setState(() {
        _pinInput = _pinInput.substring(0, _pinInput.length - 1);
      });
    }
  }

  Future<void> _showForgotPinDialog() async {
    final passwordController = TextEditingController();
    bool showPassword = false;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        UIHelper.showError(context, "User tidak ditemukan. Silakan login kembali.");
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Reset PIN Aplikasi"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Masukkan password login Anda untuk mereset PIN:",
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: "Password Login",
                    hintText: "Masukkan password",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setDialogState(() => showPassword = !showPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    "Lupa Password?",
                    style: TextStyle(
                      color: Color(0xFF0F4C5C),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (passwordController.text.isEmpty) {
                  UIHelper.showError(context, "Password tidak boleh kosong!");
                  return;
                }

                try {
                  // Verify password
                  final credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: passwordController.text.trim(),
                  );
                  await user.reauthenticateWithCredential(credential);

                  // Password BENAR. 
                  // 1. Hapus PIN lama (opsional, karena nanti akan ditimpa)
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('appLockPin');

                  if (mounted) {
                    Navigator.pop(context); // Tutup Dialog Password
                    
                    // 2. Langsung arahkan ke halaman Buat PIN Baru
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AppLockSetupPage(
                          isChanging: false, 
                          forceSetupFlow: true, // Paksa flow Buat -> Konfirmasi
                        ),
                      ),
                    );

                    // 3. Cek apakah user berhasil membuat PIN baru
                    // Jika PIN sudah ada lagi di prefs, berarti setup berhasil
                    final checkPrefs = await SharedPreferences.getInstance();
                    if (checkPrefs.containsKey('appLockPin')) {
                      if (mounted) {
                        widget.onUnlockSuccess(); // Buka kunci aplikasi
                      }
                    }
                  }
                } on FirebaseAuthException catch (e) {
                  String errorMessage = "Terjadi kesalahan";
                  if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                    errorMessage = "Password login salah!";
                  } else if (e.code == 'user-not-found') {
                    errorMessage = "User tidak ditemukan!";
                  } else if (e.code == 'requires-recent-login') {
                    errorMessage = "Sesi berakhir. Silakan login kembali.";
                  }
                  if (mounted) {
                    UIHelper.showError(context, errorMessage);
                  }
                } catch (e) {
                  if (mounted) {
                    UIHelper.showError(context, "Error: ${e.toString()}");
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4C5C),
              ),
              child: const Text("Reset & Buat Baru"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyPin() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPinHash = prefs.getString('appLockPin') ?? '';
      
      // Hash input PIN
      final inputHash = sha256.convert(utf8.encode(_pinInput)).toString();
      
      if (inputHash == savedPinHash) {
        if (mounted) {
          widget.onUnlockSuccess();
        }
      } else {
        if (mounted) {
          UIHelper.showError(context, "PIN salah. Coba lagi!");
          setState(() => _pinInput = "");
        }
      }
    } catch (e) {
      if (mounted) {
        UIHelper.showError(context, "Terjadi kesalahan: $e");
      }
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F4C5C), Color(0xFF00695C)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo/Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
              child: const Icon(
                Icons.lock,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            
            // Title
            const Text(
              "Masukkan PIN",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Aplikasi Anda dikunci. Masukkan 6 digit PIN untuk melanjutkan.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            
            // Forgot PIN Button
            TextButton(
              onPressed: _showForgotPinDialog,
              child: const Text(
                "Lupa PIN?",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // PIN Display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pinLength,
                (index) => Container(
                  // PERBAIKAN: Mengurangi width dan margin agar tidak overflow
                  width: 48,
                  height: 55,
                  margin: const EdgeInsets.symmetric(horizontal: 4), // Sebelumnya 5
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: index < _pinInput.length
                        ? Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 60),
            
            // Numpad
            _buildNumpad(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          _buildNumpadRow(['1', '2', '3']),
          const SizedBox(height: 15),
          _buildNumpadRow(['4', '5', '6']),
          const SizedBox(height: 15),
          _buildNumpadRow(['7', '8', '9']),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 70),
              _buildNumButton('0'),
              GestureDetector(
                onTap: _isLoading ? null : _removeDigit,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.backspace,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers
          .map((number) => _buildNumButton(number))
          .toList(),
    );
  }

  Widget _buildNumButton(String number) {
    return GestureDetector(
      onTap: _isLoading ? null : () => _addDigit(number),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.2),
          border: Border.all(
            color: Colors.white.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}