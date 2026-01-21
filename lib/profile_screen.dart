import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';
import 'login_screen.dart';
import 'forgot_password_screen.dart';
import 'about_screen.dart';
import 'privacy_policy_screen.dart';
import 'notification_service.dart';
import 'app_lock_setup_page.dart';
import 'package:artoku_app/services/ui_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color primaryColor = const Color(0xFF0F4C5C);

  // State Notifikasi
  bool _isNotificationOn = false;
  bool _isLoadingPrefs = true;

  // State App Lock
  bool _isAppLockEnabled = false;
  bool _isLoadingAppLock = true;

  final User? currentUser = FirebaseAuth.instance.currentUser;
  late Stream<DocumentSnapshot>? _userStream;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
    _loadAppLockPreference();

    if (currentUser != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .snapshots();
    } else {
      _userStream = null;
    }
  }

  // --- LOGIC NOTIFIKASI (JANGAN DIUBAH) ---
  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isNotificationOn = prefs.getBool('daily_reminder') ?? false;
        _isLoadingPrefs = false;
      });
    }
  }

  // --- LOGIC APP LOCK ---
  Future<void> _loadAppLockPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isAppLockEnabled = prefs.getBool('appLockEnabled') ?? false;
        _isLoadingAppLock = false;
      });
    }
  }

  Future<void> _handleAppLockToggle(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final hasPin = prefs.containsKey('appLockPin');

    if (value) {
      // Tombol ON
      if (!hasPin) {
        // Pertama kali: minta setup PIN
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AppLockSetupPage(isChanging: false),
          ),
        );
        
        if (mounted) {
          _loadAppLockPreference();
        }
      } else {
        // Sudah ada PIN sebelumnya: langsung aktifkan
        await prefs.setBool('appLockEnabled', true);
        if (mounted) {
          setState(() => _isAppLockEnabled = true);
          UIHelper.showSuccess(
            context,
            "Kunci Aplikasi Diaktifkan",
            "Aplikasi Anda sekarang dilindungi dengan PIN.",
          );
        }
      }
    } else {
      // Tombol OFF: langsung nonaktifkan
      await prefs.setBool('appLockEnabled', false);
      if (mounted) {
        setState(() => _isAppLockEnabled = false);
        UIHelper.showSuccess(
          context,
          "Kunci Aplikasi Dinonaktifkan",
          "Aplikasi Anda tidak lagi dikunci dengan PIN.",
        );
      }
    }
  }

  void _showAppLockMenu() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPin = prefs.containsKey('appLockPin');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(context).cardColor,
        title: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),
              const Text(
                "Kelola Kunci Aplikasi",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasPin)
              _buildAppLockMenuOption(
                icon: Icons.edit_note,
                title: "Ubah PIN",
                subtitle: "Ganti dengan PIN baru",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AppLockSetupPage(isChanging: true),
                    ),
                  );
                },
              ),
            if (hasPin)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: Colors.grey.withOpacity(0.3)),
              ),
            _buildAppLockMenuOption(
              icon: Icons.lock_reset,
              title: "Lupa PIN",
              subtitle: "Reset PIN dengan password login",
              onTap: () {
                Navigator.pop(context);
                _showForgotPinDialog();
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Colors.grey.withOpacity(0.3)),
            ),
            _buildAppLockMenuOption(
              icon: Icons.info_outline,
              title: "Cara Kerja",
              subtitle: "Pelajari tentang fitur ini",
              onTap: () {
                Navigator.pop(context);
                _showAppLockInfoDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }

  Widget _buildAppLockMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showForgotPinDialog() async {
    final passwordController = TextEditingController();
    bool isLoading = false;
    bool obscureText = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Theme.of(context).cardColor,
              title: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_reset,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Reset PIN",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Untuk keamanan, masukkan password login Anda untuk mereset PIN aplikasi.",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Password Login",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    obscureText: obscureText,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: "Masukkan password login",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF0F4C5C),
                          width: 2,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureText ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureText = !obscureText;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () {
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
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (passwordController.text.isEmpty) {
                            UIHelper.showError(context, "Password tidak boleh kosong!");
                            return;
                          }

                          setState(() {
                            isLoading = true;
                          });

                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null || user.email == null) {
                              if (mounted) {
                                UIHelper.showError(context, "User tidak ditemukan!");
                              }
                              return;
                            }

                            // Verifikasi password
                            final credential = EmailAuthProvider.credential(
                              email: user.email!,
                              password: passwordController.text.trim(),
                            );

                            await user.reauthenticateWithCredential(credential);

                            // Reset PIN lama
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('appLockPin');
                            await prefs.setBool('appLockEnabled', false);

                            if (mounted) {
                              Navigator.pop(context); // Tutup dialog password

                              // Buka halaman Buat PIN Baru
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AppLockSetupPage(
                                    isChanging: false,
                                    forceSetupFlow: true,
                                  ),
                                ),
                              );

                              // Setelah kembali dari AppLockSetupPage (yang sekarang sudah benar-benar tertutup)
                              // Kita update tampilan switch di Profile
                              if (mounted) {
                                _loadAppLockPreference();
                              }
                            }
                          } on FirebaseAuthException catch (e) {
                            String message = "Terjadi kesalahan.";
                            if (e.code == 'wrong-password' ||
                                e.code == 'invalid-credential') {
                              message = "Password login salah. Coba lagi!";
                            } else if (e.code == 'user-not-found') {
                              message = "User tidak ditemukan.";
                            }

                            if (mounted) {
                              UIHelper.showError(context, message);
                            }
                          } catch (e) {
                            if (mounted) {
                              UIHelper.showError(context, "Gagal: $e");
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                isLoading = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    disabledBackgroundColor: primaryColor.withOpacity(0.5),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text("Reset & Buat Baru"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAppLockInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(context).cardColor,
        title: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.help_outline,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Text(
                  "Tentang Kunci Aplikasi",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoSection(
                title: "Apa itu Kunci Aplikasi?",
                content: "Fitur keamanan yang melindungi data Anda dengan PIN 6 digit. Ketika membuka aplikasi, Anda harus memasukkan PIN untuk mengakses.",
              ),
              const SizedBox(height: 16),
              _buildInfoSection(
                title: "Kapan PIN Diminta?",
                content: "• Ketika membuka aplikasi setelah menutupnya\n• Saat aplikasi berjalan di background lebih dari 30 detik",
              ),
              const SizedBox(height: 16),
              _buildInfoSection(
                title: "Tips Keamanan",
                content: "• Gunakan PIN yang mudah diingat namun kuat\n• Jangan bagikan PIN ke siapa pun\n• Ubah PIN secara berkala\n• Jangan gunakan PIN yang sama dengan password login",
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Mengerti"),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Color(0xFF0F4C5C),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
      ],
    );
  }

  void _handleNotificationToggle(bool value) async {
    setState(() => _isNotificationOn = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_reminder', value);

    if (value) {
      await NotificationService().requestPermissions();
      await NotificationService().scheduleAllReminders();
      if (mounted) {
        UIHelper.showSuccess(
          context,
          "Pengingat Aktif!",
          "Siap Bos! Kami akan ingatkan kamu jam 12:00 (Siang) & 20:00 (Malam).",
        );
      }
    } else {
      await NotificationService().cancelAllNotifications();
      if (mounted) {
        UIHelper.showSuccess(
          context,
          "Pengingat Mati",
          "Jangan lupa catat sendiri ya. Hati-hati lupa! 🥺",
        );
      }
    }
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/icon_ArtoKu.png',
              height: 60,
              width: 60,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.language, size: 50, color: Colors.blue),
            ),
            const SizedBox(height: 15),
            const Text(
              "Fitur Segera Hadir!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Saat ini ArtoKu hanya tersedia dalam Bahasa Indonesia.\n\n"
              "Tim kami sedang belajar bahasa lain agar ArtoKu bisa go international! 🚀",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Siap Menunggu"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = themeNotifier.value == ThemeMode.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildLiveHeader(),
            const SizedBox(height: 20),
            _buildMenuSection(isDark),
            const SizedBox(height: 30),
            _buildLogoutButton(),
            _buildDeleteAccountButton(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveHeader() {
    if (currentUser == null) {
      return _buildHeaderUI("Guest", "Please Login", null);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, snapshot) {
        String displayEmail = currentUser!.email ?? "-";
        String displayName = currentUser!.displayName ?? "Nama Belum Diatur";
        String? photoBase64 = currentUser!.photoURL; // Ini fallback Auth

        if (snapshot.hasData && snapshot.data!.exists) {
          Map<String, dynamic> data =
              snapshot.data!.data() as Map<String, dynamic>;

          if (data['fullName'] != null && data['fullName'].isNotEmpty) {
            displayName = data['fullName'];
          }
          // Ambil photoURL dari Firestore (Prioritas)
          if (data['photoURL'] != null && data['photoURL'].isNotEmpty) {
            photoBase64 = data['photoURL'];
          }
        }

        return _buildHeaderUI(displayName, displayEmail, photoBase64);
      },
    );
  }

  Widget _buildHeaderUI(String name, String email, String? photoString) {
    ImageProvider imageProvider;

    if (photoString != null && photoString.isNotEmpty) {
      if (photoString.startsWith('http')) {
        imageProvider = NetworkImage(photoString);
      } else {
        try {
          Uint8List imageBytes = base64Decode(photoString);
          imageProvider = MemoryImage(imageBytes);
        } catch (e) {
          imageProvider = const AssetImage('assets/images/welcome_image.png');
        }
      }
    } else {
      imageProvider = const AssetImage('assets/images/welcome_image.png');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F4C5C), Color(0xFF00695C)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            // Fitur Lihat Foto Besar
                            showDialog(
                              context: context,
                              builder: (ctx) => Dialog(
                                backgroundColor: Colors.transparent,
                                insetPadding: const EdgeInsets.all(20),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.5),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(21),
                                    child: Image(
                                      image: imageProvider,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            backgroundImage: imageProvider,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    email,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildGroupTitle("Account Settings"),
          _buildMenuCard([
            _buildMenuItem(Icons.person_outline, "Ubah Profil", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfilePage(),
                ),
              );
            }),
            _buildDivider(),
            _buildMenuItem(Icons.lock_outline, "Ganti Password", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordPage(),
                ),
              );
            }),
            _buildDivider(),
            _buildMenuItem(Icons.info_outline, "Tentang Saya & App", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            }),
          ]),
          const SizedBox(height: 20),
          _buildGroupTitle("App Settings"),
          _buildMenuCard([
            _buildSwitchItem(
              Icons.notifications_outlined,
              "Pengingat Harian",
              _isNotificationOn,
              _handleNotificationToggle,
            ),
            _buildDivider(),
            // TOGGLE TEMA DENGAN SIMPAN PREFS
            _buildSwitchItem(Icons.dark_mode_outlined, "Mode Gelap", isDark, (
              val,
            ) async {
              themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isDarkMode', val);
              setState(() {});
            }),
            _buildDivider(),
            _buildSwitchItem(
              Icons.lock_outline,
              "Kunci Aplikasi",
              _isAppLockEnabled,
              _handleAppLockToggle,
            ),
            if (_isAppLockEnabled)
              Column(
                children: [
                  _buildDivider(),
                  _buildMenuItem(
                    Icons.security,
                    "Kelola PIN",
                    () => _showAppLockMenu(),
                  ),
                ],
              ),
            _buildDivider(),
            _buildMenuItem(Icons.language, "Bahasa", () {
              _showLanguageDialog();
            }),
            _buildDivider(),
            _buildMenuItem(Icons.privacy_tip_outlined, "Kebijakan Privasi", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            }),
          ]),
        ],
      ),
    );
  }

  Widget _buildGroupTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 10),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem(
    IconData icon,
    String title,
    bool value,
    Function(bool) onChanged,
  ) {
    bool isLoadingItem = _isLoadingPrefs;
    if (icon == Icons.lock_outline) {
      isLoadingItem = _isLoadingAppLock;
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      trailing: isLoadingItem
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(
              value: value,
              activeColor: primaryColor,
              onChanged: onChanged,
            ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 60, endIndent: 20);
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.redAccent),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Keluar Akun"),
                content: const Text("Apakah Anda yakin ingin keluar?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Batal"),
                  ),
                  TextButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    child: const Text(
                      "Ya, Keluar",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
          },
          child: const Text(
            "Keluar",
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: TextButton(
        onPressed: _showDeleteConfirmationDialog,
        child: const Text(
          "Hapus Akun",
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Akun?"),
        content: const Text(
          "Tindakan ini tidak bisa dibatalkan. Semua data Anda, termasuk riwayat transaksi, akan dihapus secara permanen. Apakah Anda yakin?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close the first dialog
              _showPasswordReauthenticationDialog();
            },
            child: const Text("Ya, Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showPasswordReauthenticationDialog() {
    final passwordController = TextEditingController();
    bool isLoading = false;
    bool obscureText = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Konfirmasi Password"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Untuk keamanan, masukkan password Anda untuk melanjutkan."),
                  const SizedBox(height: 15),
                  TextField(
                    controller: passwordController,
                    obscureText: obscureText,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureText ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureText = !obscureText;
                          });
                        },
                      ),
                    ),
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal"),
                ),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() {
                            isLoading = true;
                          });
                          
                          // This context is for the dialog
                          // final dialogNavigator = Navigator.of(context); // This variable is unused and causes a warning.

                          await _deleteAccount(passwordController.text.trim());
                          
                          // Check if the widget is still in the tree before updating state.
                          if (mounted) {
                            // If deletion was successful, dialog would already be popped.
                            // If failed, we are still here.
                            setState(() {
                              isLoading = false;
                            });
                          }
                          // If deletion fails, the dialog stays open for another try.
                        },
                  child: const Text("Konfirmasi Hapus", style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteAccount(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    // Capture the context outside of async calls
    final navigator = Navigator.of(context); 

    if (user == null || user.email == null) {
      if (mounted) UIHelper.showError(context, "Tidak ada user yang login.");
      return;
    }

    try {
      // 1. Re-authenticate
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // 2. Delete Firestore data (user document)
      // This does not delete sub-collections like 'transactions'.
      // A complete solution would use a Cloud Function to delete all related data.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      
      // 3. Delete the Firebase Auth user
      await user.delete();

      // 4. Navigate to login screen
      // Pop the re-auth dialog first.
      navigator.pop(); 
      if (mounted) {
        UIHelper.showSuccess(context, "Akun Dihapus", "Akun Anda telah berhasil dihapus.");
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }

    } on FirebaseAuthException catch (e) {
      String message = "Terjadi kesalahan.";
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          message = "Password salah. Silakan coba lagi.";
      } else if (e.code == 'requires-recent-login') {
          message = "Sesi Anda telah berakhir. Silakan login kembali dan coba lagi.";
      }
      
      // Pop the dialog and show error on the main screen
      navigator.pop(); 
      if(mounted) UIHelper.showError(context, message);

    } catch (e) {
      // Pop the dialog and show error on the main screen
      navigator.pop(); 
      if (mounted) {
        UIHelper.showError(context, "Gagal menghapus akun: $e");
      }
    }
  }
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  File? _selectedImage;
  String? _currentPhotoData;

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  String _initialName = "";
  String _initialPhone = "";

  @override
  void initState() {
    super.initState();
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? "";
    }
    _loadUserData();
    // Add listeners to rebuild the widget when text changes, to update button visibility
    _nameController.addListener(() => setState(() {}));
    _phoneController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    // Dispose controllers to free up resources
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        DocumentSnapshot userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userData.exists && mounted) {
          Map<String, dynamic> data = userData.data() as Map<String, dynamic>;
          String dbName = data['fullName'] ?? '';
          String dbPhone = data['phone'] ?? '';
          String dbPhoto = data['photoURL'] ?? '';

          setState(() {
            _nameController.text = dbName;
            _phoneController.text = dbPhone;
            _currentPhotoData = dbPhoto;

            // Store initial values to compare against for changes
            _initialName = dbName;
            _initialPhone = dbPhone;
          });
        }
      } catch (e) {
        if (mounted) UIHelper.showError(context, "Gagal memuat data: $e");
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // Getter to check if any data has been changed
  bool get _hasChanges {
    return _nameController.text.trim() != _initialName ||
        _phoneController.text.trim() != _initialPhone ||
        _selectedImage != null;
  }

  Future<void> _handleBackNavigation() async {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }
    final bool shouldDiscard = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Batalkan Perubahan?"),
            content: const Text("Perubahan belum disimpan. Yakin keluar?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Tidak"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Ya, Keluar",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldDiscard && mounted) {
      Navigator.pop(context);
    }
  }

  // Returns true if launch was successful, false otherwise.
  Future<bool> _launchWhatsApp() async {
    const String adminPhoneNumber = "62882008525112";
    const String message = "Halo";
    final Uri whatsappUrl = Uri.parse(
      "https://wa.me/$adminPhoneNumber?text=${Uri.encodeComponent(message)}",
    );

    try {
      // launchUrl returns a bool. If it's false, it means the OS couldn't handle the URL.
      final bool launched =
          await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        UIHelper.showError(context,
            "Tidak dapat membuka WhatsApp. Pastikan aplikasi WhatsApp sudah terinstall.");
      }
      return launched;
    } catch (e) {
      if (mounted) {
        UIHelper.showError(context,
            "Terjadi kesalahan. Pastikan WhatsApp sudah terinstall di perangkat Anda.");
      }
      return false;
    }
  }

  Future<void> _saveProfile() async {
    final navigator = Navigator.of(context);
    // --- 1. VALIDATION ---
    String inputPhone = _phoneController.text.trim();
    if (inputPhone.isNotEmpty &&
        !inputPhone.startsWith('08') &&
        !inputPhone.startsWith('62')) {
      UIHelper.showError(context, "Nomor HP harus berawalan '08' atau '62'");
      return;
    }
    if (inputPhone.isNotEmpty && inputPhone.length < 10) {
      UIHelper.showError(context, "Nomor HP terlalu pendek (min 10 digit)!");
      return;
    }
    if (!_hasChanges) return;

    setState(() => _isLoading = true);
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final bool isPhoneChanged = inputPhone != _initialPhone;
      final bool isNameChanged = _nameController.text.trim() != _initialName;
      final bool isPhotoChanged = _selectedImage != null;

      // --- 2. PHONE NUMBER UNIQUENESS CHECK ---
      if (isPhoneChanged && inputPhone.isNotEmpty) {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: inputPhone)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          UIHelper.showError(
              context, "Nomor telepon ini sudah terdaftar oleh pengguna lain.");
          setState(() => _isLoading = false);
          return;
        }
      }

      // --- 3. SAVE DATA TO FIRESTORE & AUTH ---
      String? newPhotoData = _currentPhotoData;
      if (isPhotoChanged) {
        final bytes = await _selectedImage!.readAsBytes();
        newPhotoData = base64Encode(bytes);
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'fullName': _nameController.text.trim(),
          'phone': inputPhone,
          'email': _emailController.text.trim(),
          'photoURL': newPhotoData,
          'lastUpdated': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );

      if (isNameChanged) {
        await user.updateDisplayName(_nameController.text.trim());
      }

      // --- 4. HANDLE UI FLOW BASED ON CHANGES ---
      if (isPhoneChanged) {
        // If phone number changes, show the WhatsApp dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text("Terhubung dengan ArtoBot ✅"),
              content: const Text(
                  "Terima kasih telah menambahkan nomor telepon. "
                    "Anda bisa langsung menghubungi ArtoBot via WhatsApp dengan klik tombol Hubungi ArtoBot dibawah ini."),
              actions: <Widget>[
                TextButton(
                  child: const Text("Tutup"),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Hubungi ArtoBot",
                      style: TextStyle(color: Colors.white)),
                  onPressed: () async {
                    if (await _launchWhatsApp()) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
        navigator.pop(); // Pop back to profile screen
      } else if (isNameChanged || isPhotoChanged) {
        // If only name or photo changed, show a simple success dialog
        await showDialog(
            context: context,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text("Berhasil"),
                content: const Text("Profil Anda telah berhasil diperbarui."),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text("OK"),
                  )
                ],
              );
            });
        navigator.pop(); // Pop back to profile screen
      }
    } catch (e) {
      if (mounted) UIHelper.showError(context, "Gagal menyimpan: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? returnedImage = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 25,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (returnedImage != null) {
      // This setState call will trigger a rebuild and _hasChanges will be re-evaluated
      setState(() => _selectedImage = File(returnedImage.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF0F4C5C);

    ImageProvider currentImageProvider;
    if (_selectedImage != null) {
      currentImageProvider = FileImage(_selectedImage!);
    } else if (_currentPhotoData != null && _currentPhotoData!.isNotEmpty) {
      if (_currentPhotoData!.startsWith('http')) {
        currentImageProvider = NetworkImage(_currentPhotoData!);
      } else {
        try {
          Uint8List bytes = base64Decode(_currentPhotoData!);
          currentImageProvider = MemoryImage(bytes);
        } catch (e) {
          currentImageProvider =
              const AssetImage('assets/images/welcome_image.png');
        }
      }
    } else {
      currentImageProvider = const AssetImage('assets/images/welcome_image.png');
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Ubah Profil"),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: _handleBackNavigation,
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              border: Border.all(width: 4, color: Colors.white),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  spreadRadius: 2,
                                  blurRadius: 10,
                                  color: Colors.black.withOpacity(0.1),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: currentImageProvider,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  width: 4,
                                  color: Colors.white,
                                ),
                                color: primaryColor,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Klik gambar untuk mengubah",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 30),
                    _buildTextField(
                      "Nama Lengkap",
                      "Masukkan nama lengkap Anda",
                      _nameController,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      "E-mail",
                      "Masukkan e-mail Anda",
                      _emailController,
                      isReadOnly: true,
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          "Nomor Telepon",
                          "Contoh: 08123456789",
                          _phoneController,
                          keyboardType: TextInputType.number,
                          formatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(15),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    // This button is now conditionally visible
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _hasChanges && !_isLoading ? _saveProfile : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          disabledBackgroundColor: primaryColor.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          "Simpan Perubahan",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String placeholder,
    TextEditingController controller, {
    bool isReadOnly = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: isReadOnly,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          style: TextStyle(
            color: isReadOnly
                ? (isDark ? Colors.white54 : Colors.grey)
                : (isDark ? Colors.white : Colors.black),
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
            filled: isReadOnly,
            fillColor: isReadOnly
                ? (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200])
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFF0F4C5C), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _oldPassController.addListener(() => setState(() {}));
    _newPassController.addListener(() => setState(() {}));
    _confirmPassController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _oldPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  bool get _isFormComplete => 
      _oldPassController.text.isNotEmpty &&
      _newPassController.text.isNotEmpty &&
      _confirmPassController.text.isNotEmpty;

  Future<void> _changePassword() async {
    final navigator = Navigator.of(context);
    
    if (_oldPassController.text.isEmpty ||
        _newPassController.text.isEmpty ||
        _confirmPassController.text.isEmpty) {
      UIHelper.showError(context, "Semua kolom harus diisi!");
      return;
    }
    if (_newPassController.text != _confirmPassController.text) {
      UIHelper.showError(context, "Password baru tidak cocok!");
      return;
    }
    if (_newPassController.text.length < 6) {
      UIHelper.showError(context, "Password minimal 6 karakter");
      return;
    }

    setState(() => _isLoading = true);
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null && user.email != null) {
      try {
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _oldPassController.text.trim(),
        );
        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(_newPassController.text.trim());
        
        if (mounted) {
          // Show success dialog first
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text("Berhasil"),
                content: const Text(
                  "Password Anda telah berhasil diubah. "
                  "Untuk keamanan, silakan login kembali dengan password baru.",
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text("OK"),
                  ),
                ],
              );
            },
          );
          
          // Then sign out and navigate to login
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        String message = "Gagal mengganti password.";
        if (e.code == 'wrong-password') {
          message = "Password lama salah.";
        } else if (e.code == 'weak-password') {
          message = "Password baru terlalu lemah.";
        } else if (e.code == 'requires-recent-login') {
          message = "Sesi Anda telah berakhir. Silakan login kembali dan coba lagi.";
        }

        if (mounted) {
          UIHelper.showError(context, message);
        }
      } catch (e) {
        if (mounted) {
          UIHelper.showError(context, "Error: $e");
        }
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF0F4C5C);
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
          "Ganti Password",
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
            const Text(
              "Ganti Password Anda",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Password baru Anda harus berbeda dari password sebelumnya.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            _buildPasswordField(
              "Password Lama",
              _oldPassController,
              _obscureOld,
              () {
                setState(() => _obscureOld = !_obscureOld);
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ForgotPasswordScreen(),
                    ),
                  );
                },
                child: Text(
                  "Lupa Password Lama?",
                  style: TextStyle(color: primaryColor, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildPasswordField(
              "Password Baru",
              _newPassController,
              _obscureNew,
              () {
                setState(() => _obscureNew = !_obscureNew);
              },
            ),
            const SizedBox(height: 20),
            _buildPasswordField(
              "Konfirmasi Password Baru",
              _confirmPassController,
              _obscureConfirm,
              () {
                setState(() => _obscureConfirm = !_obscureConfirm);
              },
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_isFormComplete && !_isLoading) ? _changePassword : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  disabledBackgroundColor: primaryColor.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Reset Password",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller,
    bool isObscure,
    VoidCallback onIconTap,
  ) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isObscure,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: "••••••••",
            hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFF0F4C5C), width: 2),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isObscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: onIconTap,
            ),
          ),
        ),
      ],
    );
  }
}
