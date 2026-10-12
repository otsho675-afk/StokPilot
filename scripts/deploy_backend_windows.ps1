# Bu betik yalnizca stokpilot-5bd2e projesine temel backend'i dagitir.
# RevenueCat webhook sirri ayarlanana dek ucretli webhook'u dagitmaz.
$ErrorActionPreference = 'Stop'
$project = 'stokpilot-5bd2e'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  throw 'Firebase CLI eksik. Once npm install -g firebase-tools komutunu calistirin.'
}

# Windows'ta Node.js 23/24/25 firebase komutundan sonra libuv assert ile
# dusebilir; bu durum basarili kimlik dogrulamayi oturum hatasi gibi gostermemeli.
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  throw 'Node.js bulunamadi. Firebase CLI icin Node.js 22 LTS kurun.'
}
$nodeVersion = (& node --version).Trim()
Write-Host "Node.js: $nodeVersion; Firebase projesi: $project" -ForegroundColor Cyan
if ($nodeVersion -match '^v(\d+)' -and [int]$Matches[1] -ge 23) {
  Write-Warning 'Node.js 23 ve sonrasi Windows surumlerinde UV_HANDLE_CLOSING kapanis hatasi gorulebiliyor. Komutlar cokuyorsa Node.js 22 LTS kullanin.'
}
Write-Host 'Oturum kontrolu icin projects:list cagrisi atlandi. Dagitim hatasi varsa Firebase gercek nedeni gosterecek.' -ForegroundColor Cyan

Write-Host 'Firestore kurallari ve indeksler dagitiliyor...' -ForegroundColor Cyan
firebase deploy --only firestore --project $project
if ($LASTEXITCODE -ne 0) { throw 'Firestore dagitimi basarisiz. Firebase CLI cikisini inceleyin; UV_HANDLE_CLOSING varsa Node.js 22 LTS kullanin.' }

Write-Host 'StokPilot icin gerekli Firebase Cloud Functions dagitiliyor (europe-west1)...' -ForegroundColor Cyan
$functions = 'functions:initializeWorkspace,functions:createProduct,functions:commitTrade,functions:postPayment,functions:adjustStock,functions:deleteAccount'
firebase deploy --only $functions --project $project
if ($LASTEXITCODE -ne 0) { throw 'Fonksiyon dagitimi basarisiz. Blaze plani/API izinlerini ve varsa UV_HANDLE_CLOSING Node.js kapanis hatasini inceleyin.' }

Write-Host 'Son kontrol - initializeWorkspace, createProduct ve diger fonksiyonlar listede olmali:' -ForegroundColor Green
firebase functions:list --project $project
if ($LASTEXITCODE -ne 0) { Write-Warning 'Fonksiyon listesi kontrolunde Firebase CLI hatasi var; basarili dagitim iddiasi icin Firebase Console > Functions uzerinden kontrol edin.' }
Write-Host 'Dagitim komutlari tamamlandi. Firebase Console > Functions bolumunde europe-west1/initializeWorkspace goruldugunde Flutter icinde Tekrar dene basin.' -ForegroundColor Green
