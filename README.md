# ArtoKu - Smart Finance Manager 💰🚀

![ArtoKu Banner](assets/images/icon_ArtoKu.png)

**ArtoKu** adalah aplikasi manajemen keuangan pribadi berbasis **Flutter** yang dirancang untuk memudahkan pencatatan arus kas harian. Aplikasi ini mengintegrasikan kecerdasan buatan (**Gemini AI**) untuk mempercepat pencatatan transaksi melalui pemindaian struk dan input suara, serta menyediakan laporan keuangan yang komprehensif.

[![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Backend-Firebase-FFCA28?style=for-the-badge&logo=firebase)](https://firebase.google.com/)
[![Gemini AI](https://img.shields.io/badge/Powered%20by-Gemini%20AI-8E75B2?style=for-the-badge&logo=google)](https://deepmind.google/technologies/gemini/)

## ✨ Fitur Unggulan

* **🤖 Integrasi AI (Gemini):**
    * **Scan Struk:** Foto struk belanja, AI akan otomatis mengekstrak total harga, kategori, dan nama item.
    * **Voice Input:** Perintah suara (contoh: *"Beli kopi 20 ribu pakai gopay"*), AI akan mencatatnya ke kategori dan dompet yang tepat.
* **📊 Analisis Keuangan:** Visualisasi pengeluaran dan pemasukan menggunakan Pie Chart dan Bar Chart yang interaktif.
* **📄 Laporan PDF:** Ekspor laporan keuangan bulanan ke dalam format PDF siap cetak.
* **👛 Manajemen Dompet:** Kelola berbagai sumber dana (Tunai, Bank, E-Wallet) dan fitur kunci dompet (*lock wallet*).
* **🔔 Daily Reminder:** Notifikasi terjadwal (Siang & Malam) agar konsisten mencatat transaksi.
* **🔐 Keamanan Tinggi:** Mendukung Login Email, Google Sign-In, dan **Biometrik** (Fingerprint/Face ID).
* **🎨 Tampilan Modern:** Mendukung **Dark Mode** dan Light Mode yang elegan.

## 📸 Screenshots

| Dashboard | Analisis | Scan AI | Laporan PDF |
|:---:|:---:|:---:|:---:|
| <img src="screenshots/dashboard.png" width="200" alt="Dashboard"/> | <img src="screenshots/analysis.png" width="200" alt="Analisis"/> | <img src="screenshots/scan.png" width="200" alt="Scan AI"/> | <img src="screenshots/pdf.png" width="200" alt="PDF Report"/> |

*(Catatan: Screenshot diambil dari aplikasi ArtoKu)*

## 🛠️ Tech Stack

* **Framework:** Flutter (Dart)
* **Backend:** Firebase Auth, Cloud Firestore
* **AI:** Google Generative AI SDK (`google_generative_ai`)
* **State Management:** `setState` & `StreamBuilder` (Realtime Updates)
* **Packages Utama:**
    * `fl_chart` (Grafik)
    * `flutter_local_notifications` (Notifikasi Lokal)
    * `pdf` & `printing` (Generate PDF)
    * `local_auth` (Biometrik)
    * `image_picker` (Kamera/Galeri)
    * `flutter_dotenv` (Keamanan API Key)
    * `speech_to_text` (Input Suara)

## 🚀 Cara Instalasi & Menjalankan

Ikuti langkah ini untuk menjalankan ArtoKu di komputer lokal Anda:

### 1. Prerequisites
Pastikan Anda telah menginstall:
* [Flutter SDK](https://docs.flutter.dev/get-started/install)
* Android Studio / VS Code
* Git

### 2. Clone Repository
```bash
git clone [https://github.com/RestuAgilYA/artoku_app.git](https://github.com/RestuAgilYA/artoku_app.git)
cd artoku_app

```

### 3. Install Dependencies

```bash
flutter pub get

```

### 4. Konfigurasi Environment (.env)

Buat file bernama `.env` di *root folder* project (sejajar dengan `pubspec.yaml`), lalu isi dengan API Key Gemini Anda:

```env
GEMINI_API_KEY=AIzaSyCvatWS289x-mQNyqITAeD2YspRmLCuqsc

```

*Dapatkan API Key di [Google AI Studio](https://aistudio.google.com/).*

### 5. Konfigurasi Firebase

Aplikasi ini membutuhkan konfigurasi Firebase project Anda sendiri:

1. Buat project baru di [Firebase Console](https://console.firebase.google.com/).
2. Aktifkan **Authentication** (Email/Password & Google).
3. Aktifkan **Firestore Database**.
4. Download file konfigurasi:
* **Android:** `google-services.json` -> letakkan di `android/app/`.
* **iOS:** `GoogleService-Info.plist` -> letakkan di `ios/Runner/`.



### 6. Jalankan Aplikasi

```bash
flutter run

```

## 📂 Struktur Folder

```
lib/
├── services/
│   ├── gemini_service.dart      # Logic Integrasi AI
│   ├── notification_service.dart # Logic Notifikasi Lokal
│   ├── auth_service.dart        # Logic Google Sign-In
│   ├── ui_helper.dart           # Custom Dialog & Toast
│   └── logger_service.dart      # Error Logging
├── ..._screen.dart              # Halaman UI (Dashboard, Login, Report, dll)
├── ..._sheet.dart               # Bottom Sheets (Add Transaction)
├── pdf_helper.dart              # Generator Laporan PDF
└── main.dart                    # Entry point & Config

```

## 🤝 Kontribusi

Kontribusi sangat diterima! Jika Anda menemukan bug atau ingin menambahkan fitur:

1. Fork repository ini.
2. Buat branch fitur baru (`git checkout -b fitur-keren`).
3. Commit perubahan Anda (`git commit -m 'Menambahkan fitur keren'`).
4. Push ke branch (`git push origin fitur-keren`).
5. Buat Pull Request.

## 👨‍💻 Author

**Restu Agil Yuli Arjun**

* LinkedIn: [Restu Agil Yuli Arjun](https://www.linkedin.com/in/restuagilya/)
* GitHub: [@RestuAgilYA](https://github.com/RestuAgilYA)
* Instagram: [@_restuagil](https://www.instagram.com/_restuagil/)
* Email: [restuagil.ya@gmail.com](mailto:restuagil.ya@gmail.com)

---