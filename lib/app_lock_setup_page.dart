import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:artoku_app/services/ui_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:artoku_app/forgot_password_screen.dart';
import 'package:app_links/app_links.dart'; // [BARU]
import 'dart:async'; // [BARU]

class AppLockSetupPage extends StatefulWidget {
  final bool isChanging;
  final bool forceSetupFlow;

  const AppLockSetupPage({
    super.key,
    this.isChanging = false,
    this.forceSetupFlow = false,
  });

  @override
  State<AppLockSetupPage> createState() => _AppLockSetupPageState();
}


class _AppLockSetupPageState extends State<AppLockSetupPage> {
  String _oldPin = "";
  String _newPin = "";
  String _confirmPin = "";
  bool _showNewPinStep = false;
  bool _showConfirmStep = false;
  bool _isLoading = false;
  final int _pinLength = 6;
  final Color primaryColor = const Color(0xFF0F4C5C);

  // [BARU] Variabel Deep Link
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    // Jika forceSetupFlow true, pastikan flow dua tahap (input PIN baru lalu konfirmasi)
    if (widget.forceSetupFlow) {
      _showNewPinStep = false;
      _showConfirmStep = false;
      _oldPin = "";
      _newPin = "";
      _confirmPin = "";
    }
    
    // [BARU] Inisialisasi Listener Link
    _initDeepLinkListener();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel(); // [BARU] Bersihkan listener
    super.dispose();
  }

  // --- [BARU] LOGIC DEEP LINK UNTUK RESET DI HALAMAN INI ---
  Future<void> _initDeepLinkListener() async {
    _appLinks = AppLinks();

    // Listener untuk link saat aplikasi resume (dari email)
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    // Hanya proses jika sedang di tahap verifikasi PIN lama
    if (!widget.isChanging || _showNewPinStep) return;

    String link = uri.toString();
    if (FirebaseAuth.instance.isSignInWithEmailLink(link)) {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('emailForPinReset');

      if (savedEmail != null) {
        try {
          if (mounted) UIHelper.showLoading(context);

          // Verifikasi Link
          await FirebaseAuth.instance.signInWithEmailLink(
            email: savedEmail,
            emailLink: link,
          );

          await prefs.remove('emailForPinReset');

          if (mounted) {
            Navigator.pop(context); // Tutup loading
            // SUKSES: Langsung ke tahap PIN Baru
            _skipToNewPinStep();
          }
        } catch (e) {
          if (mounted) {
            Navigator.pop(context);
            UIHelper.showError(context, "Link tidak valid/expired.");
          }
        }
      }
    }
  }

  // --- [BARU] LOGIC BUTTON LUPA PIN ---
  Future<void> _showForgotPinDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool isGoogleUser = user.providerData.any((info) => info.providerId == 'google.com');

    if (isGoogleUser) {
      _showGoogleResetDialog(user);
    } else {
      _showPasswordResetDialog(user);
    }
  }

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
              await _sendResetEmail(user.email!);
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

  Future<void> _sendResetEmail(String email) async {
    UIHelper.showLoading(context);
    try {
      var acs = ActionCodeSettings(
        url: 'https://artoku-20712.firebaseapp.com/reset-pin', // Domain Anda
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
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('emailForPinReset', email);

      if (mounted) {
        Navigator.pop(context);
        UIHelper.showSuccess(context, "Link Terkirim", "Cek email Anda dan klik linknya.");
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        UIHelper.showError(context, "Gagal: $e");
      }
    }
  }

  Future<void> _showPasswordResetDialog(User user) async {
    final passwordController = TextEditingController();
    bool showPassword = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Verifikasi Password"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: passwordController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: "Password Login",
                    suffixIcon: IconButton(
                      icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => showPassword = !showPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
                    },
                    child: Text("Lupa Password?", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(
              onPressed: () async {
                try {
                  final credential = EmailAuthProvider.credential(email: user.email!, password: passwordController.text.trim());
                  await user.reauthenticateWithCredential(credential);
                  if (mounted) {
                    Navigator.pop(context);
                    _skipToNewPinStep(); // Sukses -> Lanjut ke PIN Baru
                  }
                } catch (e) {
                  UIHelper.showError(context, "Password salah!");
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: const Text("Verifikasi", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _skipToNewPinStep() async {
    // Hapus PIN lama dari storage agar bersih
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('appLockPin');

    setState(() {
      _oldPin = ""; // Reset input lama
      _showNewPinStep = true; // Pindah ke step PIN Baru
    });
    
    if (mounted) {
      UIHelper.showSuccess(context, "Verifikasi Berhasil", "Silakan buat PIN baru Anda.");
    }
  }

  // --- EXISTING LOGIC ---

  void _addDigit(String digit) {
    if (widget.isChanging && !_showNewPinStep) {
      if (_oldPin.length < _pinLength) {
        setState(() {
          _oldPin += digit;
        });
      }
    } else if (!_showConfirmStep && _showNewPinStep) {
      if (_newPin.length < _pinLength) {
        setState(() {
          _newPin += digit;
        });
      }
    } else if (_showConfirmStep) {
      if (_confirmPin.length < _pinLength) {
        setState(() {
          _confirmPin += digit;
        });
        if (_confirmPin.length == _pinLength) {
          _verifyAndSave();
        }
      }
    } else {
      if (_newPin.length < _pinLength) {
        setState(() {
          _newPin += digit;
        });
      }
    }
  }

  void _removeDigit() {
    if (widget.isChanging && !_showNewPinStep) {
      if (_oldPin.isNotEmpty) {
        setState(() {
          _oldPin = _oldPin.substring(0, _oldPin.length - 1);
        });
      }
    } else if (!_showConfirmStep && _showNewPinStep) {
      if (_newPin.isNotEmpty) {
        setState(() {
          _newPin = _newPin.substring(0, _newPin.length - 1);
        });
      }
    } else if (_showConfirmStep) {
      if (_confirmPin.isNotEmpty) {
        setState(() {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        });
      }
    } else {
      if (_newPin.isNotEmpty) {
        setState(() {
          _newPin = _newPin.substring(0, _newPin.length - 1);
        });
      }
    }
  }

  void _proceedToConfirm() {
    if (_newPin.length != _pinLength) {
      UIHelper.showError(context, "PIN harus 6 digit!");
      return;
    }
    setState(() => _showConfirmStep = true);
  }

  Future<void> _verifyOldPin() async {
    if (_oldPin.length != _pinLength) {
      UIHelper.showError(context, "PIN harus 6 digit!");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedPinHash = prefs.getString('appLockPin') ?? '';
    final inputHash = sha256.convert(utf8.encode(_oldPin)).toString();

    if (inputHash != savedPinHash) {
      if (mounted) {
        UIHelper.showError(context, "PIN lama salah. Coba lagi!");
      }
      setState(() => _oldPin = "");
      return;
    }

    if (mounted) {
      setState(() {
        _showNewPinStep = true;
      });
    }
  }

  void _backToFirstStep() {
    if (_showConfirmStep) {
      setState(() {
        _showConfirmStep = false;
        _confirmPin = "";
      });
    } else if (widget.isChanging && _showNewPinStep) {
      setState(() {
        _showNewPinStep = false;
        _newPin = "";
      });
    }
  }

  Future<void> _verifyAndSave() async {
    if (_newPin != _confirmPin) {
      if (mounted) {
        UIHelper.showError(context, "PIN tidak cocok. Coba lagi!");
      }
      setState(() {
        _confirmPin = "";
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final pinHash = sha256.convert(utf8.encode(_newPin)).toString();
      final currentUser = FirebaseAuth.instance.currentUser;
      
      await prefs.setString('appLockPin', pinHash);
      await prefs.setBool('appLockEnabled', true);
      
      // Simpan UID user untuk validasi kepemilikan PIN
      if (currentUser != null) {
        await prefs.setString('appLockUid', currentUser.uid);
      }

      if (mounted) {
        // Tampilkan pesan sukses
        UIHelper.showSuccess(
          context,
          "Berhasil",
          widget.isChanging 
            ? "PIN aplikasi berhasil diubah."
            : "PIN aplikasi berhasil dibuat.",
        );
        
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.pop(context); 
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        UIHelper.showError(context, "Gagal menyimpan PIN: $e");
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    String currentPin;
    String title;
    String subtitle;
    bool showLanjutButton = false;
    
    // Flag untuk menampilkan tombol Lupa PIN
    bool showForgotPinButton = false;

    if (widget.isChanging && !_showNewPinStep) {
      currentPin = _oldPin;
      title = "Verifikasi PIN Lama";
      subtitle = "Masukkan PIN lama Anda untuk konfirmasi";
      showLanjutButton = _oldPin.length == _pinLength;
      showForgotPinButton = true; // [BARU] Tampilkan tombol di step ini
    } else if (_showConfirmStep) {
      currentPin = _confirmPin;
      title = "Konfirmasi PIN Baru";
      subtitle = "Masukkan kembali PIN baru Anda untuk konfirmasi";
      showLanjutButton = false;
    } else {
      currentPin = _newPin;
      title = (widget.isChanging ? "PIN Baru" : "Buat PIN");
      subtitle = "Masukkan 6 digit PIN untuk kunci aplikasi Anda";
      showLanjutButton = _newPin.length == _pinLength;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isLoading
            ? null
            : IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).iconTheme.color,
                ),
                onPressed: (_showConfirmStep || (widget.isChanging && _showNewPinStep))
                    ? _backToFirstStep
                    : () => Navigator.pop(context),
              ),
        title: Text(
          widget.isChanging ? "Ubah PIN Aplikasi" : "Kunci Aplikasi",
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // [BARU] Tombol Lupa PIN (Hanya di mode Ubah PIN step awal)
            if (showForgotPinButton)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: TextButton(
                    onPressed: _showForgotPinDialog,
                    child: Text(
                      "Lupa PIN?",
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
            
            if (!showForgotPinButton) const SizedBox(height: 20),

            // PIN Display
            LayoutBuilder(
              builder: (context, constraints) {
                // Hitung width yang responsif berdasarkan lebar layar
                final availableWidth = constraints.maxWidth;
                final totalMargin = 6.0 * 2 * 6; // 6 boxes dengan margin kiri-kanan
                final calculatedWidth = ((availableWidth - totalMargin) / 6).clamp(40.0, 55.0);
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    6,
                    (index) => Container(
                      width: calculatedWidth,
                      height: calculatedWidth * 1.1, // Proporsi height sedikit lebih tinggi
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: index < currentPin.length
                            ? Container(
                                width: calculatedWidth * 0.28, // Proporsi dot relatif terhadap box
                                height: calculatedWidth * 0.28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: primaryColor,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 60),

            // Numpad
            _buildNumpad(),
            const SizedBox(height: 40),

            // Action Button
            if (showLanjutButton)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (widget.isChanging && !_showNewPinStep && !widget.forceSetupFlow) {
                      _verifyOldPin();
                    } else {
                      _proceedToConfirm();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    disabledBackgroundColor: primaryColor.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    widget.isChanging && !_showNewPinStep ? "Verifikasi" : "Lanjutkan",
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
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
              _buildBackspaceButton(),
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _isLoading ? null : () => _addDigit(number),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.grey[800] : Colors.grey[100],
          border: Border.all(
            color: primaryColor.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _isLoading ? null : _removeDigit,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.grey[800] : Colors.grey[100],
          border: Border.all(
            color: primaryColor.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.backspace,
          color: primaryColor,
          size: 24,
        ),
      ),
    );
  }
}