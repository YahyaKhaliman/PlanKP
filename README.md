# PlanKP – Sistem Penjadwalan Maintenance (Frontend)

PlanKP adalah aplikasi mobile & desktop berbasis **Flutter** yang dirancang khusus untuk mempermudah tim General Affairs (GA), IT Support, dan Driver di lingkungan **Kencana Print** dalam mengelola, merencanakan, serta memonitor realisasi kegiatan preventive maintenance aset perusahaan secara periodik.

---

## 🚀 Fitur Utama

- **Autentikasi & Otorisasi**: Manajemen sesi aman dengan JWT, login/register, dan pembatasan hak akses berbasis Jabatan (Admin, Teknisi, IT Support, dll.) serta Divisi.
- **Master Data**: Kelola jenis aset, daftar inventaris aktif, template checklist pemeriksaan, data pabrik, dan akun user.
- **Preventive Maintenance**: Penjadwalan otomatis berdasarkan frekuensi (**Harian**, **Mingguan**, dan **Bulanan**) dengan target unit per periode.
- **Eksekusi Realisasi**: Pengisian lembar checklist kerja secara digital, unggah bukti foto maintenance, dan pembubuhan tanda tangan (signature) digital langsung dari aplikasi.
- **Dashboard & Analitik**: Ringkasan capaian preventive maintenance, jadwal terdekat, tingkat kepatuhan (kepatuhan %), dan alur panduan operasional admin baru.

---

## 📁 Struktur Folder Utama

```text
lib/
├── core/
│   ├── constants/       # Konstanta global, rute navigasi, & kunci storage
│   └── utils/           # Klien HTTP kustom (ApiClient) & helper
├── features/
│   ├── auth/            # Modul login, register, dan Provider autentikasi
│   ├── dashboard/       # Layar dashboard utama & grafik ringkasan KPI
│   ├── jadwal/          # Modul penjadwalan & form realisasi
│   └── master/          # CRUD Jenis, Inventaris, User, Checklist Template, dll.
└── main.dart            # Titik masuk utama aplikasi (setup tema, routing, & provider)
```

---

## ⚙️ Persyaratan Sistem

Sebelum memulai, pastikan perangkat Anda telah terpasang software berikut:
- **Flutter SDK**: `>= 3.0.0 < 4.0.0`
- **Dart SDK**: Terintegrasi dengan Flutter SDK
- **Java Development Kit (JDK)**: Versi 11 atau yang lebih baru (untuk build Android)
- **Android Studio** / **VS Code** beserta ekstensi Flutter & Dart

---

## 🛠️ Langkah Instalasi & Setup Lokal

### 1. Unduh Dependency
Jalankan perintah berikut pada direktori proyek untuk mengunduh semua package yang dideklarasikan pada `pubspec.yaml`:
```bash
flutter pub get
```

### 2. Konfigurasi Environment (Variabel Lingkungan)
Aplikasi ini mendukung konfigurasi environment menggunakan fitur bawaan Flutter `--dart-define-from-file`.
1. Salin berkas `.env.example` menjadi `.env` di root direktori proyek:
   ```bash
   cp .env.example .env
   ```
2. Buka berkas `.env` baru tersebut dan sesuaikan URL sesuai lingkungan development Anda:
   ```env
   API_BASE_URL=http://localhost:3003/api
   UPDATE_MANIFEST_URL=http://localhost:8183/releases/latest.json
   ```
   *Catatan: Jika Anda menguji menggunakan emulator Android, gunakan IP `http://10.0.2.2:3003/api`.*

### 3. Menjalankan Aplikasi di Lokal
Jalankan aplikasi di perangkat emulator, physical device, atau browser dengan menyertakan konfigurasi environment:
```bash
flutter run --dart-define-from-file=.env
```

Jika Anda ingin menjalankan tanpa file `.env` (fallback otomatis akan mengarah ke alamat server produksi internal Kencana Print):
```bash
flutter run
```

---

## 📦 Build untuk Produksi

Untuk mendistribusikan aplikasi ke lingkungan produksi, jalankan perintah build dengan menyertakan file `.env` produksi:

### Android (APK)
```bash
flutter build apk --release --dart-define-from-file=.env
```
Hasil file APK dapat ditemukan di direktori: `build/app/outputs/flutter-apk/app-release.apk`.

### Android (App Bundle / AAB untuk Play Store)
```bash
flutter build appbundle --release --dart-define-from-file=.env
```

### Windows Desktop
```bash
flutter build windows --release --dart-define-from-file=.env
```

### iOS (Memerlukan macOS & Xcode)
```bash
flutter build ipa --release --dart-define-from-file=.env
```

---

## 🛡️ Keamanan & Storage Lokal
- Token autentikasi JWT disimpan secara aman di dalam memori penyimpanan perangkat menggunakan **Flutter Secure Storage** (Keychain untuk iOS, Keystore untuk Android) sehingga tidak mudah diakses oleh aplikasi luar.
- Konfigurasi API tersimpan di dalam berkas [app_constants.dart](lib/core/constants/app_constants.dart) menggunakan konstruktor `const` agar nilai environment di-inject langsung saat build-time, menghindari overhead pembacaan berkas pada runtime.
