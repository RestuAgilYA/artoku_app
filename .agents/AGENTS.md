# ArtoKu Project Rules & Context

## Project Overview
- **Name:** ArtoKu
- **Framework:** Flutter (Dart)
- **Primary Function:** Aplikasi pengelolaan keuangan (Pemasukan, Pengeluaran, Rekap Harian) dengan fitur export ke PDF dan integrasi notifikasi (Pengingat harian).
- **Architecture:** Standar Flutter, kemungkinan menggunakan arsitektur modular per-fitur (seperti `features/profile/...`).
- **State Management:** Menggunakan bawaan framework seperti `setState` dan `ValueNotifier` untuk state lokal sederhana.

## Tech Stack & Core Libraries
- **Backend & Auth:** Firebase Core, Firebase Auth, Cloud Firestore, Firebase Storage.
- **Login Providers:** Google Sign-In, Local Auth (Biometrik).
- **UI & Styling:** Google Fonts, Cupertino Icons.
- **Data Visualization & Export:** fl_chart (grafik), pdf & printing (ekspor data), csv (ekspor csv).
- **Notifications & Background:** flutter_local_notifications (notifikasi lokal), timezone (manajemen waktu/zona waktu Asia/Jakarta), permission_handler (manajemen izin).
- **AI & Integrations:** google_generative_ai (Gemini), speech_to_text (voice input).
- **Remote Config & Update:** firebase_remote_config, package_info_plus (pengecekan versi update wajib).

## Important Technical Guidelines (Rules)

1. **Android Build (Release)**
   - Saat ini `minifyEnabled` dan `shrinkResources` diatur menjadi **false** pada konfigurasi `android/app/build.gradle.kts` versi release.
   - Hal ini dilakukan agar kode internal plugin seperti `flutter_local_notifications` dan `permission_handler` tidak di-obfuscate oleh R8 yang dapat memicu `PlatformException` (misal gagal menjadwalkan notifikasi).
   - Jangan menyalakan fitur minify (R8) kecuali aturan ProGuard (proguard-rules.pro) telah sangat disesuaikan dan diuji menyeluruh di device fisik.

2. **Notifications (Pengingat Harian)**
   - Notifikasi harian diset menggunakan `flutter_local_notifications` (menggunakan channel `channel_daily_reminder_artoku_v2`).
   - Waktu pengingat default: Pukul 12:15 dan 20:00 (Zona Waktu `Asia/Jakarta`).
   - Izin *Exact Alarm* (Android 12+) tidak wajib namun direkomendasikan. Aplikasi memiliki *fallback* otomatis (mode `inexactAllowWhileIdle`) jika izin *Exact Alarm* tidak diberikan.
   - Pengecekan izin sepenuhnya dilakukan sebelum penjadwalan.

3. **Remote Config & Forced Updates**
   - Aplikasi menggunakan `firebase_remote_config` untuk memverifikasi `latestVersion`.
   - Proses parsing versi menggunakan class `_VersionParts` untuk membandingkan secara detail bagian *major*, *minor*, *patch*, dan *build*.
   - Widget `_GuestUpdateWrapper` telah disediakan untuk pengguna yang belum login (di Welcome Screen) sehingga notifikasi update juga muncul kepada mereka.

4. **Environment Variables (.env)**
   - Variabel sensitif (seperti API keys untuk AI) dimuat melalui paket `flutter_dotenv`. 
   - Jangan pernah menyertakan / meng-commit `.env` ke public repository. Selalu baca dari memori menggunakan `dotenv.env['KEY']`.

5. **Style & Code Formatting**
   - Gunakan tanda kutip tunggal (`'...'`) untuk *string literals* standar pada file Dart.
   - Usahakan kode UI direfactor (dipecah menjadi method/widget kecil) bila mulai terlalu panjang atau bersarang dalam (*deeply nested*).

6. **State Management & UI Performance**
   - Hati-hati dengan `StreamBuilder` di dalam metode `build()` atau `PageView`. Selalu deklarasikan *stream* (misalnya dari Firestore) di dalam `initState()` dan simpan ke variabel, lalu gunakan variabel tersebut di `StreamBuilder`. Ini mencegah *flickering* (layar berkedip/memuat ulang) saat terjadi `setState`.
   - Gunakan `AutomaticKeepAliveClientMixin` (atau `KeepAliveWrapper`) untuk mempertahankan *state* anak dari `PageView` agar tidak dihancurkan saat digeser (*swipe*).

7. **Agent Instruction**
   - Gunakan informasi di atas sebagai acuan (*ground truth*) dalam menjawab atau memperbaiki bug di proyek ini ke depannya.
   - Selalu pertimbangkan implikasi *Permission* di versi Android baru (13, 14) tiap kali mengubah kode terkait fitur native (notifikasi, file, kamera).

8. **UI Consistency (Pop-ups & Dialogs)**
   - Untuk menampilkan pesan ke pengguna (Sukses, Gagal, Info), selalu gunakan fungsi global yang ada di `UIHelper` (`lib/core/services/ui_helper.dart`):
     - `UIHelper.showSuccess(context, title, message)`
     - `UIHelper.showError(context, message)`
     - `UIHelper.showInfo(context, title, message)`
   - Hindari membuat `AlertDialog` atau pop-up *success/error* manual secara berulang. Pop-up di `UIHelper` sudah dilengkapi dengan animasi ikon bawaan.
