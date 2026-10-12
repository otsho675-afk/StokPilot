$ErrorActionPreference = 'Stop'
Write-Host 'StokPilot Flutter + Firebase kurulumu' -ForegroundColor Cyan
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Flutter PATH uzerinde degil. https://docs.flutter.dev/get-started/install/windows' }
if (-not (Get-Command dart -ErrorAction SilentlyContinue)) { throw 'Dart PATH uzerinde degil.' }
flutter create --project-name stokpilot --org com.yesildas --platforms android,ios .
if ($LASTEXITCODE -ne 0) { throw 'Flutter platform klasorleri olusturulamadi.' }
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get basarisiz.' }
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { throw 'Firebase CLI icin Node.js ve npm kurulu olmali.' }
npm install -g firebase-tools
if ($LASTEXITCODE -ne 0) { throw 'firebase-tools kurulamadi.' }
dart pub global activate flutterfire_cli
if ($LASTEXITCODE -ne 0) { throw 'flutterfire_cli kurulamadi.' }
$env:Path = "$env:Path;$env:LOCALAPPDATA\Pub\Cache\bin"
dart run flutter_launcher_icons
if ($LASTEXITCODE -ne 0) { Write-Warning 'Ikon olusturma basarisiz.' }
dart run flutter_native_splash:create
if ($LASTEXITCODE -ne 0) { Write-Warning 'Splash olusturma basarisiz.' }
Write-Host 'Firebase hesabiniza giris yapin.' -ForegroundColor Yellow
firebase login
if ($LASTEXITCODE -ne 0) { throw 'firebase login basarisiz.' }
$flutterfire = Get-Command flutterfire -ErrorAction SilentlyContinue
if (-not $flutterfire) { throw 'flutterfire bulunamadi. Terminali yeniden acin, Pub Cache bin yolunu PATH e ekleyin.' }
flutterfire configure --project=stokpilot-5bd2e --platforms=android,ios --android-package-name=com.yesildas.stokpilot --ios-bundle-id=com.yesildas.stokpilot
if ($LASTEXITCODE -ne 0) { throw 'FlutterFire yapilandirma basarisiz.' }
Write-Host 'Baslangic dosyalari hazir. Firebase servislerini Konsoldan etkinlestirin.' -ForegroundColor Green
Write-Host 'Spark (ucretsiz) Firestore dagitimi: firebase deploy --only firestore --project stokpilot-5bd2e'
Write-Host 'Uygulamayi calistir: flutter run'
