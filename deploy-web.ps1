<#
=============================================================================
  Script Otomasi Build & Deploy Web (PlanKP)
  Autentikasi: SSH Key id_ed25519_IT-Yahya_VPS1
  Target Host : kencana@103.94.238.252
  Target Path : /var/www/PlanKP
=============================================================================
#>

$ErrorActionPreference = "Stop"

# ── 1. Konfigurasi SSH & VPS ────────────────────────────────────────────────
$SSH_KEY      = "$env:USERPROFILE\.ssh\id_ed25519_IT-Yahya_VPS1"
$VPS_USER     = "kencana"
$VPS_HOST     = "103.94.238.252"
$VPS_PATH     = "/var/www/PlanKP/build/web"
$PROD_API_URL = "http://103.94.238.252:3007/api"

# Validasi file SSH Key
if (-not (Test-Path $SSH_KEY)) {
    Write-Error "File SSH Key tidak ditemukan di: $SSH_KEY"
    exit 1
}

# ── 2. Build Flutter Web Release ────────────────────────────────────────────
Write-Host ">>> [1/4] Update Dependensi & Build Flutter Web (Release)..." -ForegroundColor Cyan
flutter pub get
flutter build web --release `
    --dart-define-from-file=.env `
    --dart-define="API_BASE_URL=$PROD_API_URL"

if (-not (Test-Path "build/web/index.html")) {
    Write-Error "Hasil build Flutter Web tidak ditemukan di build/web!"
    exit 1
}

# ── 3. Kompresi Hasil Build Web (tar.gz) untuk Upload Cepat ─────────────────
Write-Host "`n>>> [2/4] Mengompres hasil build web..." -ForegroundColor Cyan
$TEMP_DIR = "build/deploy_web_out"
New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null
$ARCHIVE_FILE = "$TEMP_DIR/web-release.tar.gz"

if (Test-Path $ARCHIVE_FILE) {
    Remove-Item -Path $ARCHIVE_FILE -Force
}

# Gunakan tar bawaan Windows untuk mengompresi isi folder build/web
tar -czf $ARCHIVE_FILE -C build/web .

if (-not (Test-Path $ARCHIVE_FILE)) {
    Write-Error "Gagal membuat arsip kompresi web!"
    exit 1
}

# ── 4. Upload & Ekstrak di VPS via SSH/SCP ──────────────────────────────────
Write-Host "`n>>> [3/4] Mengunggah arsip web ke VPS..." -ForegroundColor Cyan
$sshOptions = @("-i", $SSH_KEY, "-o", "IdentitiesOnly=yes")
$scpOptions = @("-i", $SSH_KEY, "-o", "IdentitiesOnly=yes")

# Pastikan folder target di VPS ada
ssh @sshOptions "${VPS_USER}@${VPS_HOST}" "mkdir -p $VPS_PATH /tmp/plankp_web_deploy"

# Upload arsip ke folder temporary VPS
scp @scpOptions $ARCHIVE_FILE "${VPS_USER}@${VPS_HOST}:/tmp/plankp_web_deploy/web-release.tar.gz"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Gagal mengunggah file arsip web ke VPS!"
    exit 1
}

Write-Host "`n>>> [4/4] Mengekstrak file web di VPS ($VPS_PATH)..." -ForegroundColor Cyan
# Ekstrak arsip ke /var/www/PlanKP tanpa menghapus folder build/apk
ssh @sshOptions "${VPS_USER}@${VPS_HOST}" "tar -xzf /tmp/plankp_web_deploy/web-release.tar.gz -C $VPS_PATH && rm -rf /tmp/plankp_web_deploy"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Gagal mengekstrak web release di VPS!"
    exit 1
}

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host " [OK] DEPLOY WEB SELESAI!" -ForegroundColor Green
Write-Host " Lokasi VPS   : $VPS_PATH" -ForegroundColor Green
Write-Host " URL Akses    : http://${VPS_HOST}:94" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
