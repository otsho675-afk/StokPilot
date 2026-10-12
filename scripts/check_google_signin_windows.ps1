$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$jsonFile = Join-Path $root 'android\app\google-services.json'
Write-Host 'StokPilot Google Sign-In konfigurasyon kontrolu' -ForegroundColor Cyan
if (-not (Test-Path $jsonFile)) {
  Write-Warning 'android/app/google-services.json eksik. Firebase Android ayarlarindan indirin.'
} else {
  $config = Get-Content -LiteralPath $jsonFile -Raw | ConvertFrom-Json
  Write-Host ('Firebase project_id: ' + $config.project_info.project_id)
  $clients = @($config.client | Where-Object {
    $_.client_info.android_client_info.package_name -eq 'com.yesildas.stokpilot'
  })
  Write-Host ('com.yesildas.stokpilot icin Android client sayisi: ' + $clients.Count)
  if ($clients.Count -eq 0) {
    Write-Warning 'Paket adi uyusmuyor: Android applicationId degerini de kontrol edin.'
  }
  foreach ($client in $clients) {
    $web = @($client.oauth_client | Where-Object { $_.client_type -eq 3 })
    Write-Host ('Web OAuth client_type 3 sayisi: ' + $web.Count)
    if ($web.Count -eq 0) {
      Write-Warning 'Web OAuth istemcisi eksik. Google girisini acip JSON dosyasini tekrar indirin.'
    }
  }
}
if (Test-Path (Join-Path $root 'android\gradlew.bat')) {
  Write-Host 'Gradle signingReport (SHA-1 + SHA-256) baslatiliyor...' -ForegroundColor Cyan
  Push-Location (Join-Path $root 'android')
  try {
    & .\gradlew.bat signingReport
    if ($LASTEXITCODE -ne 0) { Write-Warning 'Gradle signingReport hata verdi. Android SDK/JDK ayarlarina bakin.' }
  } finally { Pop-Location }
} else {
  Write-Warning 'android/gradlew.bat yok. Flutter Android projesini olusturun.'
}
Write-Host 'SHA degerlerini Firebase Console > Project settings > Android > Add fingerprint bolumune ekleyin.' -ForegroundColor Green
