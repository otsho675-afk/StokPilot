# Bu betik yalnizca stokpilot-5bd2e projesine temel backend'i dagitir.
# RevenueCat webhook sirri ayarlanana dek ucretli webhook'u dagitmaz.
$ErrorActionPreference = 'Stop'
$project = 'stokpilot-5bd2e'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  throw 'Firebase CLI eksik. Once npm install -g firebase-tools komutunu calistirin.'
}

Write-Host 'Firebase oturumunu ve proje erisimini kontrol ediyoruz...' -ForegroundColor Cyan
firebase projects:list
if ($LASTEXITCODE -ne 0) { throw 'Firebase oturumuna girin: firebase login. Proje erisiminizi kontrol edin.' }

Write-Host 'Mevcut Firebase fonksiyonlari:' -ForegroundColor Cyan
firebase functions:list --project $project
if ($LASTEXITCODE -ne 0) { Write-Warning 'Fonksiyon listesi okunamadi. Proje izinlerini ve Blaze planini kontrol edin.' }

Write-Host 'Firestore kurallari ve indeksler dagitiliyor...' -ForegroundColor Cyan
firebase deploy --only firestore --project $project
if ($LASTEXITCODE -ne 0) { throw 'Firestore dagitimi basarisiz. Hatayi yukarida kontrol edin.' }

Write-Host 'StokPilot icin gerekli Firebase Cloud Functions dagitiliyor (europe-west1)...' -ForegroundColor Cyan
$functions = 'functions:initializeWorkspace,functions:createProduct,functions:commitTrade,functions:postPayment,functions:adjustStock,functions:deleteAccount'
firebase deploy --only $functions --project $project
if ($LASTEXITCODE -ne 0) { throw 'Fonksiyon dagitimi basarisiz. Firebase projenizde Blaze plani ve gerekli Google Cloud API izinleri bulunmali.' }

Write-Host 'Son kontrol - initializeWorkspace, createProduct ve diger fonksiyonlar listede olmali:' -ForegroundColor Green
firebase functions:list --project $project
if ($LASTEXITCODE -ne 0) { throw 'Dagitim sonrasi fonksiyon listesi alinamadi.' }
Write-Host 'Dagitim bitti. Flutter uygulamasinda Tekrar dene butonuna basin.' -ForegroundColor Green
