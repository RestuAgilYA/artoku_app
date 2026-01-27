import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:artoku_app/services/ui_helper.dart';
import 'package:artoku_app/app_lock_setup_page.dart';
import 'package:artoku_app/forgot_password_screen.dart';
import 'package:app_links/app_links.dart'; // [BARU] Untuk menangkap link
import 'dart:async'; // [BARU] Untuk StreamSubscription

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlockSuccess;

  const AppLockScreen({
    super.key,
    required this.onUnlockSuccess,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with WidgetsBindingObserver {
  String _pinInput = "";
  bool _isLoading = false;
  final int _pinLength = 6;
  final Color primaryColor = const Color(0xFF0F4C5C);

  // [BARU] Variabel untuk Deep Link
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinkListener(); // Inisialisasi listener link
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel(); // Bersihkan listener
    super.dispose();
  }

  // --- [BARU] LOGIC DEEP LINK (MAGIC LINK) ---
  Future<void> _initDeepLinkListener() async {
    _appLinks = AppLinks();

    // 1. Cek jika aplikasi dibuka DARI MATI (Cold Start) melalui link
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      // Abaikan error saat cek initial link
    }

    // 2. Cek jika aplikasi dibuka DARI BACKGROUND (Resume) melalui link
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    }, onError: (err) {
      // debugPrint("Deep Link Error: $err");
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    String link = uri.toString();

    // Validasi apakah ini link sign-in dari Firebase
    if (FirebaseAuth.instance.isSignInWithEmailLink(link)) {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('emailForPinReset');

      if (savedEmail != null) {
        try {
          if (mounted) UIHelper.showLoading(context);

          // Verifikasi Link & Login (Passwordless)
          await FirebaseAuth.instance.signInWithEmailLink(
            email: savedEmail,
            emailLink: link,
          );

          // Bersihkan email yang disimpan agar tidak dipakai ulang
          await prefs.remove('emailForPinReset');

          if (mounted) {
            Navigator.pop(context); // Tutup loading
            
            // Sukses verifikasi -> Reset PIN & Setup Baru
            await _resetAndNavigateToSetup();
          }
        } catch (e) {
          if (mounted) {
            Navigator.pop(context); // Tutup loading
            UIHelper.showError(context, "Link expired atau tidak valid. Silakan kirim ulang.");
          }
        }
      } else {
        // Email tidak ditemukan di device ini (misal user clear data atau ganti hp)
        // Jangan tampilkan error jika bukan hasil klik magic link (misal hot restart/cold start)
        // Cek: hanya tampilkan error jika deep link ini didapat dari klik link (bukan initial link tanpa proses reset)
        // Solusi: cukup abaikan tanpa pop up agar tidak mengganggu user
        // (Jika ingin lebih aman, bisa log atau debugPrint saja)
        // debugPrint("Permintaan reset tidak ditemukan di perangkat ini.");
      }
    }
  }

  // --- [BARU] LOGIC RESET & NAVIGASI ---
  Future<void> _resetAndNavigateToSetup() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Hapus PIN Lama
    await prefs.remove('appLockPin');
    
    // 2. Navigasi ke Setup PIN Baru
    if (mounted) {
      // Tutup dialog apapun yang sedang terbuka (misal dialog "Lupa PIN")
      Navigator.of(context).popUntil((route) => route.isFirst);

      // Buka halaman Setup menggunakan PUSH (agar bisa kembali dengan benar)
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AppLockSetupPage(
            isChanging: false,
            forceSetupFlow: true, // Paksa flow Buat -> Konfirmasi
          ),
        ),
      );

      // 3. Cek apakah user berhasil membuat PIN baru (sukses save)
      final checkPrefs = await SharedPreferences.getInstance();
      if (checkPrefs.containsKey('appLockPin')) {
        if (mounted) {
          widget.onUnlockSuccess(); // Buka kunci aplikasi
        }
      }
    }
  }

  // --- LOGIC INPUT PIN (TIDAK BERUBAH) ---
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

  // --- LOGIC FORGOT PIN FLOW ---
  Future<void> _showForgotPinDialog() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        UIHelper.showError(context, "User tidak ditemukan. Silakan login kembali.");
      }
      return;
    }

    // Cek Provider: Google atau Password?
    bool isGoogleUser = user.providerData.any((info) => info.providerId == 'google.com');

    if (isGoogleUser) {
      _showGoogleResetDialog(user);
    } else {
      _showPasswordResetDialog(user);
    }
  }

  // Dialog untuk User Google (Kirim Link)
  void _showGoogleResetDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Reset PIN (Akun Google)",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 40,
                  color: Color(0xFF0F4C5C),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Kirim link verifikasi ke email:",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[300]
                      : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user.email ?? "",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F4C5C),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Link ini akan melewati verifikasi PIN lama dan memungkinkan Anda membuat PIN baru.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600],
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
              Navigator.pop(context);
              if (user.email != null) {
                await _sendResetEmail(user.email!);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              "Kirim Link",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Fungsi Kirim Email Magic Link
  Future<void> _sendResetEmail(String email) async {
    UIHelper.showLoading(context);
    try {
      var acs = ActionCodeSettings(
        // Domain Project Firebase Anda (Update sesuai konfigurasi terakhir)
        url: 'https://artoku-20712.firebaseapp.com/reset-pin', 
        handleCodeInApp: true,
        iOSBundleId: 'com.example.artokuApp',
        androidPackageName: 'com.example.artoku_app',
        androidInstallApp: true,
        androidMinimumVersion: '21',
      );

      await FirebaseAuth.instance.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: acs,
      );
      
      // Simpan email untuk verifikasi nanti
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('emailForPinReset', email);

      if (mounted) {
        Navigator.pop(context); // Tutup Loading
        UIHelper.showSuccess(
          context, 
          "Link Terkirim", 
          "Silakan buka email Anda dan klik link verifikasi untuk mereset PIN."
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        UIHelper.showError(context, "Gagal mengirim email: $e");
      }
    }
  }

  // Dialog untuk User Password (Input Password - Flow Lama)
  Future<void> _showPasswordResetDialog(User user) async {
    final passwordController = TextEditingController();
    bool showPassword = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

                  // Password BENAR -> Reset
                  if (mounted) {
                    Navigator.pop(context); // Tutup dialog
                    await _resetAndNavigateToSetup();
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
              child: const Text("Reset & Buat Baru", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
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
                  width: 48,
                  height: 55,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
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
                        : const SizedBox.shrink(), // PERBAIKAN: Gunakan shrink
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