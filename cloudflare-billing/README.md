# StokPilot: RevenueCat olmadan abonelik

Premium ürün ID: stokpilot_pro_monthly. Uygulama ücretsiz, abonelik Türkiye'de 50 TL/ay.
Flutter in_app_purchase, App Store Server API, Google Play Developer API, Cloudflare Workers ve Firebase Firestore kullanılır. RevenueCat hiçbir aşamada kullanılmaz.

## İşleyiş ve güvenlik
- Kullanıcı Apple/Google'ın native mağaza satın alma ekranında ödeme yapar.
- Flutter mağaza işlem ID'sini (Apple) veya purchaseToken'ı (Google) Cloudflare /verify adresine Firebase Authentication ID token ile gönderir.
- Worker kullanıcı JWT imzasını ve claimlerini denetler; mağaza sunucusundan güncel abonelik durumunu doğrular. İstemcinin iddiasına güvenilmez.
- Tek bir mağaza aboneliği yalnızca bir Firebase UID ile eşleşebilir. Satın alma bilgileri billingPurchases koleksiyonundadır; Firestore güvenlik kuralları istemci erişimini kapatır.
- Pro hakkı yalnızca Worker tarafından entitlements/current Firestore belgesine yazılır. Worker Cron her saat abonelikleri yeniden sorgular.
- Doğrulama hazır olana kadar DIRECT_BILLING_READY=false olmalıdır.

## 1. Mağaza hazırlığı

Apple: App Store Connect üzerinde StokPilot Pro Aylık aboneliği, ID stokpilot_pro_monthly, 1 ay, 50 TRY. İlk abonelik mutlaka bir App Store uygulama sürümüyle incelemeye gönderilir.

Apple App Store Server API için Users and Access / Integrations / In-App Purchase alanında API private key (.p8), Key ID ve Issuer ID hazırlayın. Yalnızca App Store Connect upload için kullandığınız anahtarın Server API izinleri olduğunu varsaymayın.

Android: Google Play'de stokpilot_pro_monthly aylık subscription ve aktif base plan. Android package name com.yesildas.stokpilot. Firebase için kullanılan Google service account'a Play Console üzerinden subscription/order read API yetkisi verin ve Google Play Developer API'yi açın.

## 2. Worker kurulumu

Proje dosyaları cloudflare-billing klasöründe. secrets asla GitHub'a, Flutter'a veya sohbete konmaz.

PowerShell:
    cd C:\Users\HGDGFJr\StokPilot-GitHub\cloudflare-billing
    npm install
    Get-Content -Raw "C:\Guvenli\stokpilot-service-account.json" | npx wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON
    Get-Content -Raw "C:\Guvenli\AppleServerAPI.p8" | npx wrangler secret put APPLE_PRIVATE_KEY
    npx wrangler secret put APPLE_KEY_ID
    npx wrangler secret put APPLE_ISSUER_ID
    npx wrangler deploy
    Invoke-RestMethod https://stokpilot-billing.otsho675.workers.dev/health

Config in wrangler.toml: FIREBASE_PROJECT_ID=stokpilot-5bd2e, GOOGLE_PACKAGE_NAME=com.yesildas.stokpilot, APPLE_BUNDLE_ID=com.yesildas.stokpilot. Bu Bundle ID'leri mağaza kayıtlarıyla karşılaştırın.

Firestore güvenlik kurallarını ayrıca yayınlayın:
    firebase deploy --only firestore:rules --project stokpilot-5bd2e

/health sadece Worker'ın yanıt verdiğini gösterir, ödeme zincirini doğrulamaz.

## 3. Test ve yayın

PowerShell:
    flutter pub get
    flutter analyze
    flutter test
    cd cloudflare-billing
    node --test

App Store Sandbox ve Google Play lisans testçisiyle ödeme, yenileme, iptal, iade ve geri yükleme doğrulayın. Firestore'da ilgili kullanıcıya ait entitlements/current belgesi source=direct-store ve gelecekte expiresAt içermelidir. Farklı kullanıcıya bağlı bir işlemin yeniden bağlanması reddedilmelidir.

Test, Firestore rule deploy, Worker deploy, Apple ve Google yetkileri tamamlandıktan sonra GitHub repository / Settings / Secrets and variables / Actions / Variables bölümüne DIRECT_BILLING_READY=true ekleyin. Release workflow bunu yeni IPA/AAB derlemelerine taşır. Eski TestFlight uygulamasının butonu yeni sürüm olmadan açılmaz.

## Operasyonel notlar
- Apple/Google komisyonları geçerlidir; Cloudflare ücretsiz kotasının aşılması ücret doğurabilir.
- İptal, iade ve yenileme değişimleri saatlik cron kontrolünden sonra yansır. App Store Server Notifications V2 ve Google RTDN gibi olay bazlı anlık bildirim bu sürümde bulunmaz.
- App Store/Play üretim yetkileri kullanıcı hesabınıza bağlıdır. Bu repo değişiklikleri tek başına Worker'ı veya Firebase kurallarını yayınlamaz.
- Üçüncü taraf ücretli abonelik hizmeti gerekmez. Gerçek mağaza doğrulama testleri tamamlanmadan ödeme bayrağı açılmamalıdır.
