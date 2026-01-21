// FITUR KUNCI APLIKASI - UPDATE v3: TOGGLE MECHANISM & FORGOT PIN
// Dokumentasi perubahan mekanisme toggle dan fitur reset PIN

/*
=== PERUBAHAN UTAMA ===

1. ✅ PERBAIKI MEKANISME TOGGLE
   
   SEBELUM:
   - Toggle on → selalu buka setup PIN dialog
   - Tidak perlu setup jika sudah ada PIN sebelumnya
   - User bingung dengan flow
   
   SESUDAH (Smart Toggle):
   
   TOGGLE ON:
   ├─ Cek apakah PIN sudah ada sebelumnya
   ├─ JIKA BELUM ADA PIN (User baru):
   │  └─ Langsung buka AppLockSetupPage
   │     └─ User membuat PIN baru
   │        └─ Setelah setup, auto-enable lock
   └─ JIKA SUDAH ADA PIN (User existing):
      └─ Langsung aktifkan lock (tanpa dialog)
         └─ Tampilkan success notification
   
   TOGGLE OFF:
   └─ Langsung nonaktifkan lock (tanpa dialog)
      └─ Tampilkan success notification
   
   Kode Implementation:
   - _handleAppLockToggle() cek hasPin terlebih dahulu
   - Jika toggle on && !hasPin: buka setup page
   - Jika toggle on && hasPin: prefs.setBool('appLockEnabled', true)
   - Jika toggle off: prefs.setBool('appLockEnabled', false)

2. ✅ TAMBAH FITUR "LUPA PIN" DENGAN PASSWORD VERIFICATION
   
   User Flow ketika klik "Lupa PIN":
   
   Step 1: Input Password Login
   - Dialog muncul dengan form password
   - Label: "Password Login"
   - Show/hide toggle untuk visibility
   - Button "Lupa Password?" → navigate ke ForgotPasswordScreen
   
   Step 2: Verifikasi Password
   - Backend: EmailAuthProvider.reauthenticate dengan password
   - Jika benar: lanjut ke Step 3
   - Jika salah: tampil error "Password login salah"
   
   Step 3: Reset PIN
   - Hapus stored PIN dari SharedPreferences (prefs.remove('appLockPin'))
   - Disable lock (setBool('appLockEnabled', false))
   - Tampilkan success dialog "PIN Direset"
   
   Step 4: Setup PIN Baru
   - Navigate ke AppLockSetupPage(isChanging: false)
   - User membuat PIN baru dari awal
   
   Kode Implementation:
   - Method _showForgotPinDialog(): Main flow
   - FirebaseAuth reauthenticateWithCredential() untuk verify
   - SharedPreferences remove('appLockPin') untuk reset
   - Navigate ke AppLockSetupPage setelah success
   
3. ✅ TAMBAH "LUPA PIN" BUTTON DI DIALOG KELOLA KUNCI
   
   Dialog Menu:
   ┌─────────────────────────────────┐
   │ 🔒 Kelola Kunci Aplikasi        │
   ├─────────────────────────────────┤
   │ ✏️  Ubah PIN                    │ (hanya jika sudah ada PIN)
   │    Ganti dengan PIN baru       │
   ├─────────────────────────────────┤
   │ 🔄 Lupa PIN ⭐ BARU             │
   │    Reset PIN dengan password    │
   ├─────────────────────────────────┤
   │ ℹ️  Cara Kerja                  │
   │    Pelajari tentang fitur ini   │
   └─────────────────────────────────┘
   
   Setiap menu option:
   - Icon dengan background teal
   - Title + subtitle
   - Click handler yang berbeda:
     * Ubah PIN → AppLockSetupPage(isChanging: true)
     * Lupa PIN → _showForgotPinDialog()
     * Cara Kerja → _showAppLockInfoDialog()

4. ✅ REMOVE "LUPA PIN" DARI INFO DIALOG
   
   SEBELUM:
   - Info dialog punya section "Lupa PIN?"
   - Menjelaskan bisa disable lock
   
   SESUDAH:
   - Remove section "Lupa PIN?"
   - Focus pada: Apa itu, Kapan, Tips
   - "Lupa PIN" sekarang jadi button terpisah
   - Lebih professional approach: reset via password

=== FILE YANG DIUPDATE ===

1. profile_screen.dart
   
   Update Methods:
   - _handleAppLockToggle(): Smart toggle mechanism
     * Check hasPin dengan containsKey('appLockPin')
     * Logic berbeda untuk on vs off
     * Logic berbeda untuk user baru vs existing
   
   - _showAppLockMenu(): Add "Lupa PIN" option
     * Insert _buildAppLockMenuOption untuk "Lupa PIN"
     * icon: Icons.lock_reset (icon reset)
     * onTap: _showForgotPinDialog()
   
   New Methods:
   - _showForgotPinDialog(): Reset PIN dengan password
     * Async dialog dengan StatefulBuilder
     * TextField untuk password input
     * Toggle visibility untuk password
     * FirebaseAuth.reauthenticate() untuk verify
     * Handle FirebaseAuthException
     * Remove PIN dari prefs jika benar
     * Navigate ke AppLockSetupPage setelah success
   
   - Update _showAppLockInfoDialog(): Remove "Lupa PIN" section
     * Hapus _buildInfoSection untuk "Lupa PIN?"
     * Keep: Apa itu, Kapan, Tips

=== SECURITY & DATA FLOW ===

Password Verification:
1. User input password login
2. EmailAuthProvider.credential(email, password)
3. user.reauthenticateWithCredential(credential)
4. Jika berhasil:
   - Remove 'appLockPin' dari SharedPreferences
   - Set 'appLockEnabled' = false
   - Navigate ke setup page
5. Jika gagal:
   - Catch FirebaseAuthException
   - Tampilkan error message
   - Reset state, user bisa retry

Data Cleanup:
- prefs.remove('appLockPin'): Hapus PIN hash
- prefs.setBool('appLockEnabled', false): Disable lock
- Tidak ada plaintext data tersimpan
- Tidak ada recovery token yang tersimpan

=== TESTING CHECKLIST ===

Toggle Mechanism:
- [ ] Setup PIN pertama kali (toggle on, belum ada PIN)
- [ ] Verify lock aktif setelah setup
- [ ] Toggle off → lock disabled
- [ ] Toggle on kembali (sudah ada PIN) → langsung on tanpa setup
- [ ] Disable lock notification tampil dengan benar

Reset PIN Feature:
- [ ] Klik "Lupa PIN" → dialog muncul
- [ ] Password field visible dengan toggle show/hide
- [ ] Button "Lupa Password?" → navigate ke ForgotPasswordScreen
- [ ] Input password salah → error message "Password login salah"
- [ ] Input password benar → PIN berhasil direset
- [ ] Setup PIN baru setelah reset → berhasil
- [ ] Check SharedPreferences: 'appLockPin' hilang, 'appLockEnabled' = false

UI/UX:
- [ ] Dialog kelola kunci tampil dengan 3 options
- [ ] "Lupa PIN" hanya tampil jika sudah ada PIN (opsional)
- [ ] "Lupa PIN" button punya icon lock_reset
- [ ] Info dialog tidak ada section "Lupa PIN?" lagi
- [ ] Success/error notifications tampil dengan baik

=== ERROR HANDLING ===

FirebaseAuthException Codes:
- wrong-password / invalid-credential: "Password login salah"
- user-not-found: "User tidak ditemukan"
- requires-recent-login: "Sesi berakhir, coba lagi"
- General catch: Show exception message

UIHelper Integration:
- UIHelper.showError() untuk error cases
- UIHelper.showSuccess() untuk success cases
- Dialog dengan title + message
- Auto-close setelah 1.5 seconds

=== USER FLOWS ===

Flow 1: User Baru Setup PIN
1. Buka Profile
2. Go to App Settings
3. Toggle "Kunci Aplikasi" ON
4. Langsung buka AppLockSetupPage
5. Setup 6 digit PIN
6. Konfirmasi PIN
7. Lock teraktivasi

Flow 2: User Existing Toggle Lock
1. Buka Profile
2. Go to App Settings
3. Toggle "Kunci Aplikasi" ON/OFF
4. Instant activation/deactivation
5. Notification muncul

Flow 3: Reset PIN dengan Lupa
1. Buka Profile (dengan lock aktif)
2. Click "Kelola PIN"
3. Click "Lupa PIN"
4. Masukkan password login
5. Verifikasi berhasil
6. PIN direset, redirect ke setup baru
7. Setup PIN baru

Flow 4: Lupa Password Login
1. Di dialog reset PIN
2. Click "Lupa Password?"
3. Navigate ke ForgotPasswordScreen
4. Reset password login
5. Back ke reset PIN dialog
6. Masukkan password baru
7. Lanjutkan reset PIN

=== CODE EXAMPLES ===

Smart Toggle Implementation:
```dart
Future<void> _handleAppLockToggle(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  final hasPin = prefs.containsKey('appLockPin');

  if (value) {
    if (!hasPin) {
      // User baru: setup PIN
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AppLockSetupPage(isChanging: false),
        ),
      );
      if (mounted) _loadAppLockPreference();
    } else {
      // Existing: langsung on
      await prefs.setBool('appLockEnabled', true);
      if (mounted) {
        setState(() => _isAppLockEnabled = true);
        UIHelper.showSuccess(context, "Kunci Aplikasi Diaktifkan", "...");
      }
    }
  } else {
    // Off: langsung off
    await prefs.setBool('appLockEnabled', false);
    if (mounted) {
      setState(() => _isAppLockEnabled = false);
      UIHelper.showSuccess(context, "Kunci Aplikasi Dinonaktifkan", "...");
    }
  }
}
```

Reset PIN Dialog:
```dart
Future<void> _showForgotPinDialog() async {
  final passwordController = TextEditingController();
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: "Reset PIN",
      content: TextField(
        controller: passwordController,
        obscureText: true,
        decoration: InputDecoration(labelText: "Password Login"),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Batal")),
        ElevatedButton(
          onPressed: () async {
            // Verify password
            final credential = EmailAuthProvider.credential(
              email: user.email!,
              password: passwordController.text,
            );
            await user.reauthenticateWithCredential(credential);
            
            // Reset PIN
            await prefs.remove('appLockPin');
            await prefs.setBool('appLockEnabled', false);
            
            // Setup baru
            Navigator.push(...AppLockSetupPage...);
          },
          child: Text("Reset PIN"),
        ),
      ],
    ),
  );
}
```

=== DEPLOYMENT NOTES ===

1. Testing dengan multiple scenarios:
   - Devices tanpa PIN sebelumnya
   - Devices dengan PIN active
   - Password yang salah
   - Password yang benar
   - Network issues during reauthenticate

2. Ensure SharedPreferences migration:
   - Old apps sudah punya 'appLockPin'?
   - Compatibility dengan previous version?

3. Error message clarity:
   - User harus paham password mana yang diminta
   - Jangan bingung dengan PIN dan password login

4. Navigation stack:
   - Back button behavior di forgot pin dialog
   - Post-reset PIN navigation flow

=== FUTURE ENHANCEMENTS ===

1. Timeout for wrong password attempts
2. Rate limiting untuk prevent brute force
3. Email verification sebagai alternative
4. Biometric unlock sebagai fallback
5. PIN recovery codes
*/
