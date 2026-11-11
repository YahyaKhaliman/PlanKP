<#
=============================================================================
  Script Otomasi Build & Deploy Mobile (PlanKP)
  Autentikasi: SSH Key id_ed25519_IT-Yahya_VPS1
  Target Host : kencana@103.94.238.252
  Target Path : /var/www/PlanKP/releases
=============================================================================
#>

$ErrorActionPreference = "Stop"

# ── 1. Konfigurasi SSH & VPS ────────────────────────────────────────────────
$SSH_KEY   = "$env:USERPROFILE\.ssh\id_ed25519_IT-Yahya_VPS1"
$VPS_USER  = "kencana"
$VPS_HOST  = "103.94.238.252"
$VPS_PATH  = "/var/www/PlanKP/releases"
$BASE_URL  = "http://103.94.238.252:8183/releases"

# Validasi file SSH Key
if (-not (Test-Path $SSH_KEY)) {
    Write-Error "File SSH Key tidak ditemukan di: $SSH_KEY"
    exit 1
}

# ── 2. Baca Versi Otomatis dari pubspec.yaml ────────────────────────────────
Write-Host ">>> [1/5] Membaca Versi Aplikasi..." -ForegroundColor Cyan
$pubspec = Get-Content pubspec.yaml -Raw
if ($pubspec -match "version:\s*([0-9\.]+)\+([0-9]+)") {
    $VERSION_NAME = $matches[1]
    $BUILD_NUMBER = $matches[2]
} else {
    Write-Error "Gagal membaca format versi di pubspec.yaml!"
    exit 1
}

$SHORT_SHA = (git rev-parse --short HEAD).Trim()
$APK_FILE  = "plan_kp-v${VERSION_NAME}+${BUILD_NUMBER}-${SHORT_SHA}.apk"

Write-Host "    Target Versi : v$VERSION_NAME (Build $BUILD_NUMBER)" -ForegroundColor Yellow
Write-Host "    File APK     : $APK_FILE" -ForegroundColor Yellow

# ── 3. Build APK Release ────────────────────────────────────────────────────
Write-Host "`n>>> [2/5] Mem-build APK Release (arm64-v8a)..." -ForegroundColor Cyan
flutter build apk --release `
    --target-platform android-arm64 `
    --obfuscate `
    --split-debug-info=build/app/outputs/symbols `
    --dart-define-from-file=.env

# Deteksi lokasi APK hasil kompilasi
$LOCAL_APK = "build/app/outputs/flutter-apk/app-release.apk"
if (-not (Test-Path $LOCAL_APK)) {
    $LOCAL_APK = "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
}

if (-not (Test-Path $LOCAL_APK)) {
    Write-Error "File APK tidak ditemukan di folder build output!"
    exit 1
}

# ── 4. Hitung Checksum SHA256 & Buat latest.json ────────────────────────────
Write-Host "`n>>> [3/5] Menghitung SHA256 & Menyiapkan latest.json..." -ForegroundColor Cyan
$SHA256   = (Get-FileHash -Path $LOCAL_APK -Algorithm SHA256).Hash.ToLower()
$PUB_DATE = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$LATEST_JSON = @"
{
  "version": "$VERSION_NAME",
  "buildNumber": "$BUILD_NUMBER",
  "mandatory": false,
  "notes": "Rilis Version $VERSION_NAME",
  "pub_date": "$PUB_DATE",
  "url": "$BASE_URL/$APK_FILE",
  "sha256": "$SHA256"
}
"@

New-Item -ItemType Directory -Path "build/deploy_out" -Force | Out-Null
$LATEST_JSON | Out-File -FilePath "build/deploy_out/latest.json" -Encoding utf8
Copy-Item $LOCAL_APK -Destination "build/deploy_out/$APK_FILE" -Force

# ── 5. Upload File ke VPS via SCP dengan SSH Key ────────────────────────────
Write-Host "`n>>> [4/5] Mengunggah APK dan latest.json ke VPS..." -ForegroundColor Cyan

# Parameter SCP menggunakan Private Key & IdentitiesOnly
$scpOptions = @("-i", $SSH_KEY, "-o", "IdentitiesOnly=yes")

scp @scpOptions "build/deploy_out/$APK_FILE" "${VPS_USER}@${VPS_HOST}:${VPS_PATH}/${APK_FILE}"
scp @scpOptions "build/deploy_out/latest.json" "${VPS_USER}@${VPS_HOST}:${VPS_PATH}/latest.json"

# ── 6. Bersihkan APK Versi Lama di VPS ──────────────────────────────────────
Write-Host "`n>>> [5/5] Membersihkan file APK lama di VPS..." -ForegroundColor Cyan
$sshOptions = @("-i", $SSH_KEY, "-o", "IdentitiesOnly=yes")
ssh @sshOptions "${VPS_USER}@${VPS_HOST}" "cd $VPS_PATH && ls -1t *.apk 2>/dev/null | tail -n +3 | xargs -r rm -f"

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host " [OK] RILIS SELESAI!" -ForegroundColor Green
Write-Host " URL Download : $BASE_URL/$APK_FILE" -ForegroundColor Green
Write-Host " Auto-Update  : $BASE_URL/latest.json" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
