<#
=============================================================================
  Script Otomasi Build & Deploy Mobile (PlanKP)
  Autentikasi: SSH Key id_ed25519_IT-Yahya_VPS1
  Target Host : kencana@103.94.238.252
  Target Path : /var/www/PlanKP/build/apk
=============================================================================
#>

$ErrorActionPreference = "Stop"

# ── 1. Konfigurasi SSH & VPS ────────────────────────────────────────────────
$SSH_KEY         = "$env:USERPROFILE\.ssh\id_ed25519_IT-Yahya_VPS1"
$VPS_USER        = "kencana"
$VPS_HOST        = "103.94.238.252"
$VPS_PATH        = "/var/www/PlanKP/build/apk"
$BASE_URL        = "http://103.94.238.252:8183/releases"
$PROD_API_URL    = "http://103.94.238.252:3007/api"

# Validasi file SSH Key
if (-not (Test-Path $SSH_KEY)) {
    Write-Error "File SSH Key tidak ditemukan di: $SSH_KEY"
    exit 1
}

# Validasi Release Keystore (Penting agar APK update tidak ditolak Android karena beda signature)
$KEY_PROPS_PATH = "android\key.properties"
$KEYSTORE_PATH  = "android\app\upload-keystore.jks"
if (-not (Test-Path $KEY_PROPS_PATH) -or -not (Test-Path $KEYSTORE_PATH)) {
    Write-Host "`n[PERINGATAN] Release Keystore belum lengkap!" -ForegroundColor Yellow
    Write-Host "  - android\key.properties          : $(Test-Path $KEY_PROPS_PATH)" -ForegroundColor Yellow
    Write-Host "  - android\app\upload-keystore.jks : $(Test-Path $KEYSTORE_PATH)" -ForegroundColor Yellow
    Write-Host "  Tanpa file tersebut, APK akan di-sign dengan Debug Key lokal." -ForegroundColor Yellow
    Write-Host "  HP user yang sebelumnya menginstall APK dengan Release Keystore" -ForegroundColor Yellow
    Write-Host "  harus meng-uninstall aplikasi lama terlebih dahulu jika signature berbeda.`n" -ForegroundColor Yellow
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
# Hindari karakter '+' pada nama file URL agar tidak bermasalah di URL parser / FileProvider Android
$APK_FILE  = "plan_kp-v${VERSION_NAME}-b${BUILD_NUMBER}-${SHORT_SHA}.apk"

Write-Host "    Target Versi : v$VERSION_NAME (Build $BUILD_NUMBER)" -ForegroundColor Yellow
Write-Host "    File APK     : $APK_FILE" -ForegroundColor Yellow

# ── 3. Build APK Release ────────────────────────────────────────────────────
Write-Host "`n>>> [2/5] Mem-build APK Release (arm64-v8a)..." -ForegroundColor Cyan
flutter build apk --release `
    --target-platform android-arm64 `
    --obfuscate `
    --split-debug-info=build/app/outputs/symbols `
    --dart-define-from-file=.env `
    --dart-define="API_BASE_URL=$PROD_API_URL" `
    --dart-define="UPDATE_MANIFEST_URL=$BASE_URL/latest.json"

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
  "notes": "Rilis Version $VERSION_NAME (Build $BUILD_NUMBER)",
  "pub_date": "$PUB_DATE",
  "url": "$BASE_URL/$APK_FILE",
  "sha256": "$SHA256"
}
"@

New-Item -ItemType Directory -Path "build/deploy_out" -Force | Out-Null
# Simpan latest.json sebagai UTF-8 tanpa BOM agar aman di-parse di semua perangkat
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $PWD "build/deploy_out/latest.json"), $LATEST_JSON, $utf8NoBom)
Copy-Item $LOCAL_APK -Destination "build/deploy_out/$APK_FILE" -Force

# ── 5. Upload File ke VPS via SCP dengan SSH Key ────────────────────────────
Write-Host "`n>>> [4/5] Mengunggah APK dan latest.json ke VPS ($VPS_PATH)..." -ForegroundColor Cyan

$sshOptions = @("-i", $SSH_KEY, "-o", "IdentitiesOnly=yes")
$scpOptions = @("-i", $SSH_KEY, "-o", "IdentitiesOnly=yes")

# Pastikan direktori /var/www/PlanKP/build/apk tersedia di VPS
ssh @sshOptions "${VPS_USER}@${VPS_HOST}" "mkdir -p $VPS_PATH"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Gagal membuat/mengakses direktori $VPS_PATH di VPS! Pastikan user '$VPS_USER' memiliki izin tulis (chown -R ${VPS_USER}:${VPS_USER} /var/www/PlanKP/build)."
    exit 1
}

scp @scpOptions "build/deploy_out/$APK_FILE" "${VPS_USER}@${VPS_HOST}:${VPS_PATH}/${APK_FILE}"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Gagal mengunggah $APK_FILE ke $VPS_PATH! Cek permission folder di VPS (sudo chown -R ${VPS_USER}:${VPS_USER} $VPS_PATH)."
    exit 1
}

scp @scpOptions "build/deploy_out/latest.json" "${VPS_USER}@${VPS_HOST}:${VPS_PATH}/latest.json"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Gagal mengunggah latest.json ke $VPS_PATH! Cek permission file/folder di VPS (sudo chown -R ${VPS_USER}:${VPS_USER} $VPS_PATH)."
    exit 1
}

# ── 6. Bersihkan APK Versi Lama di VPS ──────────────────────────────────────
Write-Host "`n>>> [5/5] Membersihkan file APK lama di VPS..." -ForegroundColor Cyan
ssh @sshOptions "${VPS_USER}@${VPS_HOST}" "cd $VPS_PATH && ls -1t *.apk 2>/dev/null | tail -n +3 | xargs -r rm -f"

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host " [OK] RILIS SELESAI!" -ForegroundColor Green
Write-Host " Lokasi VPS   : $VPS_PATH" -ForegroundColor Green
Write-Host " URL Download : $BASE_URL/$APK_FILE" -ForegroundColor Green
Write-Host " Auto-Update  : $BASE_URL/latest.json" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
