# PlanKP – Sistem Penjadwalan Maintenance

PlanKP adalah aplikasi Flutter yang membantu tim GA/IT/Driver Kencana Print dalam merencanakan dan memonitor realisasi maintenance aset. Sistem terdiri dari beberapa modul utama: autentikasi, master data, jadwal preventive maintenance, serta pelaporan realisasi.

## Cara Menjalankan

1. Pastikan Flutter SDK ≥ 3.0 terpasang.
2. Jalankan `flutter pub get` untuk mengunduh dependensi.
3. Sesuaikan `ApiConfig.baseUrl` pada [`lib/core/constants/app_constants.dart`](lib/core/constants/app_constants.dart:1) agar mengarah ke server backend PlanKP.
4. Jalankan aplikasi dengan `flutter run` atau build sesuai platform target: `flutter build apk --release`, `flutter build ios`, `flutter build windows`, dll.
