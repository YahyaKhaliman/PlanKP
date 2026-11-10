#!/usr/bin/env bash
set -e

echo "=== [1/3] Menarik Kode Terbaru dari Git ==="
git pull origin main

echo "=== [2/3] Update Dependensi & Build Flutter Web ==="
flutter pub get
flutter build web --release --dart-define-from-file=.env

echo "=== [3/3] Menyalin Hasil Build ke Folder Web Server ==="
TARGET_WEB="/var/www/PlanKP"
mkdir -p "$TARGET_WEB"
cp -r build/web/* "$TARGET_WEB/"

echo "=== [OK] Flutter Web Berhasil Diperbarui! ==="
