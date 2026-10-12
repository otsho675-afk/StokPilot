# Spark plan: Cloud Functions deploy edilmez. Eski betik adi geriye uyumluluk icindir.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  throw 'Firebase CLI gerekli. npm install -g firebase-tools'
}
Write-Host 'Firebase Spark: sadece Firestore kurallari ve indeksler dagitiliyor.' -ForegroundColor Cyan
firebase deploy --only firestore --project stokpilot-5bd2e
if ($LASTEXITCODE -ne 0) {
  throw 'Firestore dagitimi basarisiz. Firebase login ve Firestore veritabani ayarlarini kontrol edin.'
}
Write-Host 'Tamam! Cloud Functions ve Blaze plani gerekli degil.' -ForegroundColor Green
