# StokPilot Pro — RevenueCat kullanmadan App Store / Google Play

**Ürün:** `stokpilot_pro_monthly` — aylık otomatik yenilenen abonelik. Türkiye satış fiyatı: **50 TL/ay** (fiyatı App Store Connect ve Play Console belirler).

Bu dalda `in_app_purchase` Flutter eklentisi kullanılır. Satın alma Apple/Google mağazasında tamamlanır; Pro yetkisi cihazda **asla** verilemez. Cloudflare Worker mağazanın kendi API'sine bağlanarak aboneliği doğrular, Firestore'a sunucu kimliğiyle `source=native_store` ve `expiresAt` yazar. Firestore güvenlik kuralları istemcilerin bu alanı değiştirmesini engeller.

## 1. Mağaza ürünleri

- App Store Connect / StokPilot / Subscriptions: `stokpilot_pro_monthly`, 1 month, Türkiye 50 TRY. İlk aboneliğin uygulama sürümüyle birlikte Apple incelemesine gönderilmesi gerekir.
- Google Play Console / Monetize / Subscriptions: aynı ürün ID, 1 month, Türkiye 50 TRY. Abonelik test edilmeli ve aktif olmalıdır.
- iOS App Store ve Android Play Bundle ID / package: `com.yesildas.stokpilot`.
- Apple tarafında App Store Server API'yi kullanmaya yetkili bir **In-App Purchase / App Store Connect API anahtarı** oluştur. `.p8` anahtarının içeriğini GitHub'a/uygulamaya koyma.
- Google Cloud projesinde Google Play Android Publisher API'yi aç. Play Console > Users and permissions altında bir Google Cloud service account'a abonelik satın alma verisini okuma yetkisi ver.

## 2. Cloudflare Worker yapılandırma

`cloudflare-billing/wrangler.toml` içindeki `FIREBASE_PROJECT_ID=stokpilot-5bd2e`, `APPLE_BUNDLE_ID`, `GOOGLE_PLAY_PACKAGE_NAME` değerlerini kontrol et.

`cd cloudflare-billing` altında:

```powershell
npm install
npm test
npx wrangler login
npx wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON
npx wrangler secret put PLAY_SERVICE_ACCOUNT_JSON
npx wrangler secret put APPLE_PRIVATE_KEY_P8
npx wrangler secret put APPLE_KEY_ID
npx wrangler secret put APPLE_ISSUER_ID
npx wrangler deploy
```

**Güvenlik:** Bu secret değerlerini sohbet mesajına, GitHub dosyasına veya Flutter koduna yazma. Firebase hesabı sadece gerekli Firestore yetkilerini, Play Console service account ise minimum okuma yetkilerini taşımalı. API anahtarları sunucu tarafında kalır.

- Firebase service account'ın `project_id` alanı `stokpilot-5bd2e` olmalı.
- `GET https://stokpilot-billing.<account>.workers.dev/health` -> `{"ok":true}`.
- `POST /verify`: Firebase ID token'ı ile kimlik doğrulama + mağazadan sunucu-sunucu doğrulama + atomik Firestore satın alma sahibi kaydı. **Sadece** gerçek mağaza satın alma belgesiyle çalışır.
- Gizli anahtar eksikse `/verify` 503 döner. Satın alma açılmaz.
- Eski `/revenuecat` uç noktası kaldırılmıştır. Yeni satın almalar RevenueCat'e bağlı değildir.

## 3. Firestore güvenlik kuralları

Repo kökündeki `firestore.rules` değişti; doğrulanmış `native_store` aboneliklerine izin verir. Firestore yazma hakkı istemcilere **açılmaz**.

```powershell
firebase deploy --only firestore:rules --project stokpilot-5bd2e
```

Bu komut çalıştırılmadan ödeme açılmamalı.

## 4. GitHub build ayarları

Repository > Settings > Secrets and variables > Actions > **Variables** sekmesinde:

- `STORE_BILLING_ENDPOINT` = yayındaki HTTPS Cloudflare Worker adresi (ör. `https://stokpilot-billing.example.workers.dev`).
- `STORE_BILLING_READY` = başlangıçta **false**. **Yalnızca** sandbox satın alma/geri yükleme/yenileme ve ödeme reddi kontrolleri başarıyla doğrulandıktan sonra `true`.

`.github/workflows/store-release.yml` değişkenleri hem iOS hem Android için derlemeye geçirir. True yapılmadan mağazada ödeme butonu açılmaz.

Lokal deneme:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=STORE_BILLING_ENDPOINT=https://WORKER_ADRESI --dart-define=STORE_BILLING_READY=false
```

## 5. Yayına almadan önce tamamlanması zorunlu kontroller

- Apple/Google aboneliği mağaza tarafından onaylanmış veya test hesabına sunulmuş olmalı.
- Gerçek Sandbox iOS + Play Internal testing satın alma, yenileme, iptal, geri yükleme, yeniden yükleme testleri yapılmalı.
- Firebase Auth kimliği olmayan istekler ile sahte/başka hesap satın alma belgeleri reddedilmeli.
- Ürün kotası 50'de durmalı, doğrulanmış Pro sınırı kaldırmalı.
- **Henüz tamamlanmadı:** App Store Server Notifications V2 ve Google RTDN ile gerçek zamanlı iptal/iade/geri ödeme olaylarının işlenmesi veya güvenilir periyodik mağaza yeniden doğrulaması. Bu olmadan iade sonrası erişim mevcut `expiresAt` tarihine kadar sürebilir. Tam canlı ödeme yayınına geçmeden bu açık kapatılmalı.
- Canlı sırlar/yayın ayarları ve App Store/Play inceleme işlemleri bu repodan otomatik olarak yapılmış sayılmaz.

## Ücret bilgisi

RevenueCat kullanılmaz. `in_app_purchase` resmî Flutter eklentisi ve Cloudflare Workers'ın ücretsiz kotaları kullanılabilir; **mağaza komisyonları** ve ücretsiz kotaları aşan altyapı giderleri ayrıca geçerli olabilir.
