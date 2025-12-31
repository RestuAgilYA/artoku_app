import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';
import 'login_screen.dart';
import 'forgot_password_screen.dart';
import 'about_screen.dart';
import 'privacy_policy_screen.dart';
import 'notification_service.dart'; // Pastikan import ini ada
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

  final User? currentUser = FirebaseAuth.instance.currentUser;
  late Stream<DocumentSnapshot>? _userStream;

  @override
  void initState() {
    super.initState();
    // 1. Load status notifikasi dari memori HP
    _loadNotificationPreference();

    // 2. Setup Stream Firestore
    if (currentUser != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .snapshots();
    } else {
      _userStream = null;
    }
  }

  // --- LOGIC LOAD STATUS NOTIFIKASI ---
  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isNotificationOn = prefs.getBool('daily_reminder') ?? false;
        _isLoadingPrefs = false;
      });
    }
  }

  // --- LOGIC TOGGLE NOTIFIKASI ---
  void _handleNotificationToggle(bool value) async {
    setState(() => _isNotificationOn = value);

    // Simpan ke SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_reminder', value);

    if (value) {
      // AKTIFKAN
      // 1. Minta Izin
      await NotificationService().requestPermissions();
      // 2. Jadwalkan
      await NotificationService().scheduleAllReminders();

      if (mounted) {
        // Menggunakan UI Helper agar konsisten
        UIHelper.showSuccess(
          context,
          "Pengingat Aktif!",
          "Siap Bos! Kami akan ingatkan kamu jam 12:00 (Siang) & 20:00 (Malam).",
        );
      }
    } else {
      // MATIKAN
      await NotificationService().cancelAllNotifications();

      if (mounted) {
        // Menggunakan UI Helper
        UIHelper.showSuccess(
          // Bisa pakai showInfo jika Anda buat methodnya, tapi showSuccess juga oke
          context,
          "Pengingat Mati",
          "Jangan lupa catat sendiri ya. Hati-hati lupa! 🥺",
        );
      }
    }
  }

  // --- LOGIC LANGUAGE DIALOG (COMING SOON) ---
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pastikan aset ini ada, atau ganti errorBuilder dengan icon
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
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- BUILDER HEADER (ANTI-FLICKER) ---
  Widget _buildLiveHeader() {
    if (currentUser == null) {
      return _buildHeaderUI("Guest", "Please Login", null);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, snapshot) {
        String displayEmail = currentUser!.email ?? "-";

        // Anti-Flicker: Gunakan data Auth (Cache) dulu saat loading
        String displayName = currentUser!.displayName ?? "Nama Belum Diatur";
        String? photoBase64 = currentUser!.photoURL;

        if (snapshot.hasData && snapshot.data!.exists) {
          Map<String, dynamic> data =
              snapshot.data!.data() as Map<String, dynamic>;

          if (data['fullName'] != null && data['fullName'].isNotEmpty) {
            displayName = data['fullName'];
          }
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
          // Dekorasi Lingkaran
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

          // Tombol Back
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Konten Utama Header
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
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          backgroundImage: imageProvider,
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
            // --- TOMBOL TES NOTIFIKASI DIHAPUS (CLEAN) ---
            _buildSwitchItem(
              Icons.notifications_outlined,
              "Pengingat Harian",
              _isNotificationOn,
              _handleNotificationToggle,
            ),
            _buildDivider(),
            _buildSwitchItem(Icons.dark_mode_outlined, "Mode Gelap", isDark, (
              val,
            ) {
              themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
              setState(() {});
            }),
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
      trailing: _isLoadingPrefs
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
}

// ---------------------------------------------------------
// HALAMAN EDIT PROFILE (SUB-PAGE)
// ---------------------------------------------------------
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

        if (userData.exists) {
          Map<String, dynamic> data = userData.data() as Map<String, dynamic>;
          String dbName = data['fullName'] ?? '';
          String dbPhone = data['phone'] ?? '';
          String dbPhoto = data['photoURL'] ?? '';

          setState(() {
            _nameController.text = dbName;
            _phoneController.text = dbPhone;
            _currentPhotoData = dbPhoto;

            _initialName = dbName;
            _initialPhone = dbPhone;
          });
        }
      } catch (e) {
        print("Error loading data: $e");
      }
    }
    setState(() => _isLoading = false);
  }

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
    final bool shouldDiscard =
        await showDialog(
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

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        String? newPhotoData = _currentPhotoData;

        if (_selectedImage != null) {
          final bytes = await _selectedImage!.readAsBytes();
          String base64Image = base64Encode(bytes);
          newPhotoData = base64Image;
        }

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fullName': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'photoURL': newPhotoData,
          'lastUpdated': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));

        // Update Firebase Auth Profile juga agar cache lebih cepat
        if (_nameController.text.trim().isNotEmpty) {
          await user.updateDisplayName(_nameController.text.trim());
        }
        if (newPhotoData != null) {
          await user.updatePhotoURL(newPhotoData);
        }

        _initialName = _nameController.text.trim();
        _initialPhone = _phoneController.text.trim();
        _selectedImage = null;
        _currentPhotoData = newPhotoData;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Profile berhasil diperbarui!"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Gagal menyimpan: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickImage() async {
    final XFile? returnedImage = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 25,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (returnedImage != null) {
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
          currentImageProvider = const AssetImage(
            'assets/images/welcome_image.png',
          );
        }
      }
    } else {
      currentImageProvider = const AssetImage(
        'assets/images/welcome_image.png',
      );
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
                    _buildTextField(
                      "Nomor Telepon",
                      "Masukkan nomor telepon Anda",
                      _phoneController,
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
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

// ---------------------------------------------------------
// HALAMAN CHANGE PASSWORD (SUB-PAGE)
// ---------------------------------------------------------
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

  Future<void> _changePassword() async {
    if (_oldPassController.text.isEmpty ||
        _newPassController.text.isEmpty ||
        _confirmPassController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Semua kolom harus diisi!")));
      return;
    }
    if (_newPassController.text != _confirmPassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password baru tidak cocok!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_newPassController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password minimal 6 karakter"),
          backgroundColor: Colors.red,
        ),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Password berhasil diubah!"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } on FirebaseAuthException catch (e) {
        String message = "Gagal mengganti password.";
        if (e.code == 'wrong-password')
          message = "Password lama salah.";
        else if (e.code == 'weak-password')
          message = "Password baru terlalu lemah.";

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );
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

            // FITUR LUPA PASSWORD DI HALAMAN GANTI PASSWORD
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
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
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
