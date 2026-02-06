# ArtoKu - Smart Finance Manager 💰🚀

![ArtoKu Banner](screenshoots/artoku_banner.png)

**ArtoKu** adalah aplikasi manajemen keuangan pribadi berbasis **Flutter** yang dirancang untuk memudahkan pencatatan arus kas harian. Aplikasi ini mengintegrasikan kecerdasan buatan (**Gemini AI**) untuk mempercepat pencatatan transaksi melalui pemindaian struk dan input suara, serta menyediakan laporan keuangan yang komprehensif.

[![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Backend-Firebase-FFCA28?style=for-the-badge&logo=firebase)](https://firebase.google.com/)
[![Gemini AI](https://img.shields.io/badge/Powered%20by-Gemini%20AI-8E75B2?style=for-the-badge&logo=google-gemini)](https://deepmind.google/technologies/gemini/)

## ✨ Fitur Unggulan

* **🤖 Integrasi AI (Gemini):**
    * **Scan Struk:** Foto struk belanja, dan AI akan otomatis mengekstrak total harga, kategori, dan nama item.
    * **Voice Input:** Ucapkan transaksi Anda (contoh: *"Beli kopi 20 ribu pakai gopay"*), dan AI akan mencatatnya ke kategori dan dompet yang tepat.
* **📊 Analisis Keuangan:** Visualisasikan pengeluaran dan pemasukan menggunakan Pie Chart dan Bar Chart yang interaktif untuk mendapatkan wawasan finansial.
* **📄 Laporan PDF & CSV:** Ekspor laporan keuangan bulanan ke dalam format PDF yang siap cetak atau CSV untuk diolah lebih lanjut.
* **👛 Manajemen Dompet:** Kelola berbagai sumber dana (Tunai, Bank, E-Wallet) dan amankan dengan fitur kunci dompet (*lock wallet*).
* **🔔 Pengingat Harian:** Notifikasi terjadwal (siang & malam) untuk membantu Anda konsisten dalam mencatat setiap transaksi.
* **🔐 Keamanan Berlapis:**
    * Login dengan Email & Password atau Google Sign-In.
    * Amankan aplikasi dengan **Kunci Biometrik** (Sidik Jari/Face ID).
* **🎨 Tampilan Modern & Adaptif:**
    * Antarmuka yang bersih dan intuitif.
    * Dukungan penuh untuk **Dark Mode** dan Light Mode.

## 📸 Galeri Aplikasi

Berikut adalah beberapa cuplikan dari fitur-fitur utama ArtoKu.

| Fitur | Screenshot | Deskripsi |
| :--- | :---: | :--- |
| **Dashboard** | <img src="screenshoots\dashboard.png" width="200"/> | Halaman utama yang menampilkan ringkasan saldo, pemasukan, pengeluaran, dan transaksi terakhir. |
| **Analisis Keuangan** | <img src="screenshoots\analisa.png" width="200"/> | Visualisasi data keuangan dengan grafik lingkaran (pie chart) untuk pengeluaran per kategori. |
| **Manajemen Dompet** | <img src="screenshoots\dompet.png" width="200"/> | Kelola semua sumber dana Anda, dari tunai, rekening bank, hingga e-wallet di satu tempat. |
| **Riwayat Transaksi** | <img src="screenshoots\riwayat.png" width="200"/> | Lihat daftar lengkap semua transaksi yang pernah Anda catat, lengkap dengan detailnya. |
| **Input AI (Suara)** | <img src="screenshoots\input_ai_audio.png" width="200"/> | Cukup ucapkan transaksi Anda, dan biarkan Gemini AI mencatatnya secara otomatis. |
| **Laporan Keuangan** | <img src="screenshoots\laporan keuangan.png" width="200"/> | Hasilkan laporan keuangan dalam format PDF atau CSV untuk dianalisis lebih lanjut. |
| **Kunci Aplikasi** | <img src="screenshoots\kunci aplikasi.png" width="200"/> | Amankan data finansial Anda dengan lapisan keamanan tambahan berupa sidik jari atau PIN. |
| **Profil Pengguna** | <img src="screenshoots\profile.png" width="200"/> | Atur informasi akun Anda, ubah foto profil, dan kelola preferensi aplikasi. |

## 🛠️ Teknologi & Dependensi

*   **Framework:** Flutter (Dart)
*   **Backend:** Firebase (Authentication, Cloud Firestore)
*   **AI:** Google Generative AI SDK (`google_generative_ai`)
*   **State Management:** `setState` & `StreamBuilder` untuk pembaruan data real-time.
*   **Dependensi Utama:**
    *   `fl_chart` untuk grafik dan analisis.
    *   `flutter_local_notifications` untuk notifikasi terjadwal.
    *   `pdf` & `printing` untuk pembuatan laporan PDF.
    *   `local_auth` untuk autentikasi biometrik.
    *   `image_picker` & `speech_to_text` untuk input AI.
    *   `flutter_dotenv` untuk keamanan kunci API.
    *   `google_sign_in` untuk autentikasi Google.

## 🚀 Memulai

Ikuti langkah-langkah ini untuk menjalankan ArtoKu di lingkungan pengembangan lokal Anda.

### 1. Prasyarat
Pastikan Anda telah menginstal perangkat lunak berikut:
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (versi 3.x atau lebih baru)
*   Android Studio / VS Code
*   Git

### 2. Clone Repository
```bash
git clone https://github.com/RestuAgilYA/artoku_app.git
cd artoku_app
```

### 3. Instal Dependensi
Jalankan perintah berikut untuk mengunduh semua paket yang dibutuhkan.
```bash
flutter pub get
```

### 4. Konfigurasi Lingkungan (.env)
Buat file bernama `.env` di direktori root proyek (sejajar dengan `pubspec.yaml`), lalu isi dengan API Key Gemini Anda.
```env
GEMINI_API_KEY=*********************
```
*Anda bisa mendapatkan API Key di [Google AI Studio](https://aistudio.google.com/).*

### 5. Konfigurasi Firebase
Aplikasi ini memerlukan proyek Firebase untuk berfungsi.
1.  Buat proyek baru di [Firebase Console](https://console.firebase.google.com/).
2.  Aktifkan layanan **Authentication** (dengan provider Email/Password & Google).
3.  Aktifkan layanan **Cloud Firestore**.
4.  Daftarkan aplikasi Android dan/atau iOS Anda.
5.  Unduh file konfigurasi dan letakkan di direktori yang sesuai:
    *   **Android:** `google-services.json` -> letakkan di `android/app/`.
    *   **iOS:** `GoogleService-Info.plist` -> letakkan di `ios/Runner/`.

### 6. Jalankan Aplikasi
Sekarang Anda siap menjalankan aplikasi!
```bash
flutter run
```

## 📂 Struktur Proyek
Struktur direktori `lib` dirancang agar mudah dipahami dan dikelola.
```
lib/
├── services/               # Logika bisnis dan layanan pihak ketiga
│   ├── gemini_service.dart     # Integrasi dengan Gemini AI
│   ├── notification_service.dart # Pengelola notifikasi lokal
│   ├── auth_service.dart       # Proses autentikasi
│   ├── ui_helper.dart          # Komponen UI (Dialog, Toast)
│   └── logger_service.dart     # Pencatatan error
│
├── *_screen.dart           # Berbagai halaman utama aplikasi
├── *_sheet.dart            # Komponen Bottom Sheet
├── helpers/                # Class bantuan (PDF, CSV)
│   ├── pdf_helper.dart
│   └── csv_helper.dart
│
└── main.dart               # Titik masuk utama aplikasi
```

## 🤝 Kontribusi
Kontribusi sangat kami hargai! Jika Anda menemukan bug atau ingin menambahkan fitur baru, silakan:
1.  **Fork** repository ini.
2.  Buat **Branch** baru (`git checkout -b fitur-baru`).
3.  **Commit** perubahan Anda (`git commit -m 'Menambahkan fitur baru'`).
4.  **Push** ke branch Anda (`git push origin fitur-baru`).
5.  Buat **Pull Request**.

## 👨‍💻 Author
**Restu Agil Yuli Arjun**
*   LinkedIn: [Restu Agil Yuli Arjun](https://www.linkedin.com/in/restuagilya/)
*   GitHub: [@RestuAgilYA](https://github.com/RestuAgilYA)
*   Instagram: [@_restuagil](https://www.instagram.com/_restuagil/)
*   Email: [restuagil.ya@gmail.com](mailto:restuagil.ya@gmail.com)

---
