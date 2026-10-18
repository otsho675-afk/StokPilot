# StokPilot: RevenueCat olmadan abonelik

Premium ürün ID: stokpilot_pro_monthly. Uygulama ücretsiz, abonelik Türkiye'de 50 TL/ay.
Flutter in_app_purchase, App Store Server API, Google Play Developer API, Cloudflare Workers ve Firebase Firestore kullanılır. RevenueCat hiçbir aşamada kullanılmaz.

## İşleyiş ve güvenlik
- Kullanıcı Apple/Google'ın native mağaza satın alma ekranında ödeme yapar.
- Flutter Apple işlem ID'sini ve StoreKit 2 imzalı işlem JWS'sini veya Google purchaseToken'ını Cloudflare /verify adresine Firebase Authentication ID token ile gönderir. iOS 15 ve üzeri gerekir.
- Worker kullanıcı JWT imzasını ve claimlerini denetler. Apple'ın cihazdan gelen JWS'sinin sertifika zincirini, imzasını, ortamını, uygulama/ürün/işlem kimliğini doğrular; ardından Apple sunucusundan aynı abonelik zincirinin güncel durumunu sorgular. Apple'ın durum ve grace period JWS'leri ayrıca doğrulanır. İmzalı JWS veya eşleşen işlem yoksa Pro açılmaz.
- Yeni iOS satın almalarında Firebase UID'den türetilmiş sabit bir UUID StoreKit appAccountToken olarak gönderilir. Worker Apple'ın imzaladığı token'ı bağlanan Firebase hesabıyla karşılaştırır. Ham JWS saklanmaz; appAccountToken, daha sonraki geri yüklemelerde karşılaştırmak için yalnızca sunucudaki abonelik eşleşmesiyle tutulur. Silinmiş Firebase hesabına bağlı Apple aboneliği, ancak imzalı StoreKit kanıtıyla yeni hesaba geri yüklenebilir; yaşayan başka bir hesaba bağlı abonelik aktarılamaz.
- Tek bir mağaza aboneliği yalnızca bir Firebase UID ile eşleşebilir. Satın alma bilgileri billingPurchases koleksiyonundadır; Firestore güvenlik kuralları istemci erişimini kapatır.
- Pro hakkı yalnızca Worker tarafından entitlements/current Firestore belgesine yazılır. Worker Cron her saat abonelikleri sayfalayarak yeniden sorgular. İptal edilen abonelik ödenmiş sürenin sonuna kadar, grace period ise Apple'ın bildirdiği bitişe kadar açık kalır; süre dolunca mevcut kayıtlar silinmez.
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

`APPLE_APP_ID=6822247708`, App Store Connect'teki uygulamanın sayısal Apple ID'sidir; aboneliğin Apple ID'si (`6822256509`) veya ürün ID'si değildir. Bu herkese açık değer `wrangler.toml` içindedir. Aynı dosyada FIREBASE_PROJECT_ID=stokpilot-5bd2e, GOOGLE_PACKAGE_NAME=com.yesildas.stokpilot, APPLE_BUNDLE_ID=com.yesildas.stokpilot bulunur. Bundle ID'yi mağaza kaydıyla karşılaştırın. `src/apple-roots.js` içindeki herkese açık Apple kök sertifikaları Apple PKI'den alınmıştır; özel anahtar içermez.

Firestore güvenlik kurallarını ayrıca yayınlayın:
    firebase deploy --only firestore:rules --project stokpilot-5bd2e

/health sadece Worker'ın yanıt verdiğini gösterir, ödeme zincirini doğrulamaz.

## 3. Test ve yayın

PowerShell:
    flutter pub get
    flutter analyze
    flutter test
    cd cloudflare-billing
    npm ci
    npm test

App Store Sandbox ve Google Play lisans testçisiyle ödeme, yenileme, iptal, grace period, iade, çevrimdışı hata ve geri yükleme doğrulayın. Firestore'da ilgili kullanıcıya ait entitlements/current belgesi source=direct-store ve gelecekte expiresAt içermelidir. Farklı kullanıcıya bağlı bir işlemin yeniden bağlanması reddedilmelidir. Apple Review Information abonelik ekran görüntüsü ve inceleme notları, ücretli uygulama sözleşmesi/banka/vergi bilgileri, In-App Purchase capability ve aboneliğin uygulama sürümüne eklenmesi App Store Connect'te ayrıca kontrol edilmelidir.

Gerçek iOS sandbox testi için GitHub Actions / Build and upload store releases işini bu daldan `platform=ios`, `enable_ios_billing=true` girdileriyle elle çalıştırın. Bu yalnızca o iOS derlemesindeki StoreKit akışını açar; Android ve sonraki derlemeler etkilenmez. Bu JWS doğrulama değişikliğinden önce üretilen derlemeler sunucuya imzalı kanıt göndermez ve yeni Worker tarafından kabul edilmez. Yeni TestFlight derlemesinde satın alma, geri yükleme, iptal/süre dolma ve Firestore hakkını doğrulayın. Başarılı testler ve Apple incelemesi için doğru yeni build seçildikten sonra genel yayın derlemeleri için GitHub repository / Settings / Secrets and variables / Actions / Variables bölümüne DIRECT_BILLING_READY=true eklenebilir.

## Operasyonel notlar
- Apple/Google komisyonları geçerlidir; Cloudflare ücretsiz kotasının aşılması ücret doğurabilir.
- Ödeme kapalı derlemede de iOS mağazasının döndürdüğü yerel fiyat gösterilebilir; satın alma ve geri yükleme sunucu doğrulaması etkinleşene kadar kapalıdır. Mağaza ürün sorgusu başarısızsa fiyat tahmini gösterilmez.
- İptal, iade ve yenileme değişimleri saatlik cron kontrolünden sonra yansır. App Store Server Notifications V2 ve Google RTDN gibi olay bazlı anlık bildirim bu sürümde bulunmaz.
- App Store/Play üretim yetkileri kullanıcı hesabınıza bağlıdır. Bu repo değişiklikleri tek başına Worker'ı veya Firebase kurallarını yayınlamaz.
- Üçüncü taraf ücretli abonelik hizmeti gerekmez. Gerçek mağaza doğrulama testleri tamamlanmadan ödeme bayrağı açılmamalıdır.
