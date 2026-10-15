# StokPilot Pro aylık abonelik - Firebase Spark + RevenueCat + Cloudflare Workers

**Amaç:** Firebase Blaze kullanmadan, Google Play/App Store abonelik doğrulamasını güvenli bir sunucuda tutmak. Cloudflare Workers'ın ücretsiz kotası başlangıç için yeterli olabilir (talep ve kota değişirse ücret çıkabilir). RevenueCat Pro, aylık takip edilen 2.500 USD gelir eşiğinin altında ücretsizdir; eşik aşılınca ücret uygulanabilir. Apple/Google mağaza ücret ve komisyonları ayrıdır.

## Abonelik ürünlerini oluştur

- Google Play Console > Subscriptions: ürün `stokpilot_pro_monthly`, base plan `monthly-50`, otomatik yenileme **1 ay**, Türkiye fiyatı vergi dahil **50,00 TRY**. Plan aktiftir (15 Ekim 2026).
- App Store Connect > Subscriptions: ürün `stokpilot_pro_monthly`, otomatik yenileme **1 ay**, Türkiye hedef fiyatı **50,00 TRY**; Apple fiyatı henüz yapılandırılmadı. İlk abonelik uygulamanın yeni sürümüyle incelemeye gönderilmelidir.
- RevenueCat'te Android/iOS uygulamalarını bağla, **`pro`** entitlement oluştur, **`default`** offering içindeki `$rc_monthly`/Monthly paketini ilgili mağaza ürününe bağla.
- RevenueCat SDK **public** anahtarları Google için `goog_...`, Apple için `appl_...`; bunları Flutter `--dart-define` ile kullan.

## Google Cloud hizmet hesabı (Firebase projesini Blaze'e yükseltme)

1. Google Cloud Console'da mevcut `stokpilot-5bd2e` projesini seç.
2. IAM & Admin > Service Accounts'dan **sadece Firestore erişimli** özel hizmet hesabı oluştur. `Cloud Datastore User` rolü Firestore belge okumaya/yazmaya izin verir. Başka projeler için rol atama.
3. Service Accounts > Keys > Add Key > JSON ile yeni anahtar oluştur (kuruluş politikası engelliyorsa alternatif sunucu kimliği yaklaşımı gerekir).
4. Bu JSON'u **GitHub'a, Flutter uygulamasına veya sohbet mesajına ekleme**. Yalnızca Cloudflare Worker secret olarak yükle ve yerel kopyasını güvenli tut.

## Cloudflare kurulumu

```powershell
cd C:\Users\HGDGFJr\StokPilot-GitHub\cloudflare-billing
npm install
npx wrangler login
# Google service account JSON dosyasının yerel konumunu KENDİ dosyanıza göre değiştirin:
Get-Content -Raw "C:\Guvenli\stokpilot-service-account.json" | npx wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON
npx wrangler secret put REVENUECAT_WEBHOOK_SECRET
npx wrangler deploy
```

İkinci komut sizden uzun, rastgele bir parola isteyecek. **Bu değeri sakla**, RevenueCat Webhooks'ta aynı değeri `Authorization: Bearer <WEBHOOK_SECRET>` header'ında kullan.

Workers adresi genellikle `https://stokpilot-billing.<hesabiniz>.workers.dev` biçimindedir. RevenueCat webhook hedefi `https://...workers.dev/revenuecat` olmalı. `/health` adresi `ok` vermeli. Webhook, RevenueCat'ten gelen sipariş olayını gizli header ile doğrular; Firebase'e ait `entitlements/current` belgesini kendi IAM kimliğiyle yazar. Bu belgeyi Flutter doğrudan yazamaz.

> RevenueCat webhook tetikleyici, satın alma tamamlandığında Firebase kullanıcısının UID'sini `app_user_id` olarak taşımalıdır. Flutter kodu RevenueCat'te aynı Firebase UID ile identify yapar. RevenueCat'in rastgele anonim ID'lerine Pro yetkisi yazılmaz.

## Testten sonra satın almayı aç

**Yalnızca** Apple/Google mağaza ürünleri aktif, RevenueCat Pro entitlement bağlı, Worker yayında, secrets tanımlı ve Sandbox satın alma/iptal/yenileme akışı **başarıyla doğrulanmışsa** aşağıdaki bayrağı açın:

```powershell
flutter run --dart-define=RC_VERIFIED_BACKEND_READY=true --dart-define=RC_ANDROID_PUBLIC_KEY=goog_SIZIN_ANAHTARINIZ
```

iOS için `RC_IOS_PUBLIC_KEY=appl_SIZIN_ANAHTARINIZ`. `RC_VERIFIED_BACKEND_READY=true` yalnızca ödeme düğmesinin görünmesine izin verir; Firestore güvenliği Pro belgesinin güvenilir sunucudan gelmesine bağlıdır.

## Güvenlik ve önemli sınırlar

- Hizmet hesabı anahtarı ve webhook secret yalnızca Cloudflare Secrets'ta bulunur. Kod deposunda ve uygulama paketinde bulunmaz.
- Sunucu olay zamanına göre eski/duble olayları reddeder; Firestore optimistic concurrency kullanılır.
- `CANCELLATION` otomatik yenileme iptali demektir, mevcut ödenmiş süre bitmeden Pro kapanmaz. `EXPIRATION` veya süre sonu kurallarca erişimi kapatır.
- Kullanıcı hesabını Firebase Auth'tan silmek, mağaza aboneliğini otomatik iptal etmez.
- Worker `https://stokpilot-billing.otsho675.workers.dev` adresinde yayındadır; `/health`, kimlik doğrulama ve sentetik webhook yetki döngüsü test edilmiştir. Gerçek Apple/Google satın alma, yenileme ve iptal akışı doğrulanmadan ödeme bayrağını açmayın.

