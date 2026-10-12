# StokPilot - Firebase Spark

**GÜNCEL SÜRÜM:** Cloud Functions yerine doğrudan Firestore transaction kullanır; Firebase Blaze planına geçiş gerekmez. Ücretsiz 50 ürün sınırı Firestore kurallarıyla uygulanır. 50 TL/ay Pro abonelik **henüz ödeme doğrulaması kurulmadığından test sürümünde kapalıdır**.

Kurulumun güncel adımları: [SPARK_KURULUM.md](SPARK_KURULUM.md).

# StokPilot — Flutter + Firebase — 50 Ürün Ücretsiz, Pro ₺50/Ay

StokPilot stok, kategori, birim, KDV, cari müşteri/tedarikçi, alış, satış, tahsilat, rapor ve stok hareketleri için Flutter + Firestore + Cloud Functions tabanlı bir uygulamadır.

## Planlar ve kullanıcı akışı

| Üyelik | Ürün oluşturma sınırı | Satış / cari / stok işlemleri |
|---|---|---|
| Misafir (Firebase Anonymous) | 50 | Ücretsiz |
| Google / Apple / E-posta | 50 | Ücretsiz |
| **Pro aylık** | **Sınırsız** | Dahil |

**Hedef Türkiye fiyatı: 50,00 TL / ay** (Apple App Store Türkiye fiyat kademelerinden bulunabilen en yakın noktayı seçin; uygulamada gerçek `priceString` gösterilir). Mobil uygulama mağazada **ücretsiz indirilebilir** olmalı; ücret uygulama içinden aylık otomatik yenilenen abonelikle alınmalı.

Misafir hesabı aynı Firebase UID üzerinde `linkWithCredential` (Google) veya `linkWithProvider` (Apple) ile kalıcıya yükseltilir; var olan bir kullanıcı hesabına bağlanma çakışmasında otomatik veri taşıması yoktur. Misafir olarak çıkış yapılması durumunda veriye tekrar erişilemeyebilir; silmeden önce hesap bağlayın.

## Firestore güvenlik modeli

- `initializeWorkspace` bütün hesapları **free** statüsünde açar; eski 14 günlük deneme yeni sürümde artık yazma kapısı değildir.
- `createProduct` callable Cloud Function işlem içinde `productCount` sayısını artırır. Ücretsiz hesapta 50. kayıttan sonra engeller. İki cihazdan eş zamanlı yazma transaction ile korunur.
- **İstemci ürün oluşturamaz:** `firestore.rules` ürün `allow create: if false` yapar; callable işlem Admin SDK kullanır. Ürün düzenleme, kategori/birim/KDV, cari işlemleri ücretsizdir. Stock / trade ledger transaction fonksiyonlarıyla güncellenir.
- `productCount` tarihsel oluşturulmuş kayıt sayısıdır; ürün pasife almak ücretsiz kotayı geri kazandırmaz. Eski kurulumdan geçişte sayım backfill yapılır; eski veri varsa `productCount` değerinin doğru olduğundan emin olun.
- RevenueCat webhook doğrulanmış `pro` entitlement ile `status=active`, `source=revenuecat`, `expiresAt` yazar. Mağaza fiyatı **koddan değiştirilmez**.
- Gerçek mağaza/RevenueCat/Apple/Google kurulumları tamamlanana kadar canlı para çekimi **etkin değildir**.

## Firebase Auth giriş hatasının çözümü

Uyarı `This operation is not allowed ... sign-in provider is disabled` Firebase projesindeki ilgili sağlayıcının devre dışı olduğunu gösterir. Console: <https://console.firebase.google.com/project/stokpilot-5bd2e/authentication/providers> → Authentication → Sign-in method, **Anonymous**, **Google**, **Email/Password** (isteğe bağlı), **Apple** (Apple Developer yapılandırması sonrasında) → Enable.

Google için Android debug/release **SHA-1 + SHA-256** ekleyin. Android imza bilgisi: `cd android; ./gradlew signingReport` (Windows: `.\gradlew signingReport`). Apple için Developer → Identifiers → App ID → Sign In with Apple yeteneği, Firebase Authentication > Apple sağlayıcısı ve Xcode Signing & Capabilities > Sign In with Apple gerekir. Gerekli Apple Service ID / Key yapılandırmasını Firebase paneliyle eşleştirin. `flutterfire configure` sonra konfigürasyon dosyalarını güncelleyin.

## Windows kurulum

```powershell
cd C:\Users\HGDGFJr
# İlk defa GitHub'dan çekiyorsanız (klasör daha önce yoksa):
git clone https://github.com/otsho675-afk/StokPilot.git
cd StokPilot
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\setup_windows.ps1
firebase use stokpilot-5bd2e
firebase deploy --only firestore,functions
flutter pub get
flutter analyze
flutter test
flutter run
```

**Var olan yerel `StokPilot` klasörünüz varsa üzerine git clone yapmayın.** Önce yedek alın; mevcut projeyi uzak depoya bağlama ve birleştirme işlemini kontrollü yapın. Github'da ilk commit mevcut olmayan boş repoya kodların ilk push'unu yapmadan `git pull` çalışmaz.

Windows PowerShell FlutterFire kurulumda `flutterfire` bulunamıyorsa `dart pub global activate flutterfire_cli` ve `$env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"`. Uygulama Firebase projesi `stokpilot-5bd2e`, Android/iOS bundle `com.yesildas.stokpilot`. Firebase Cloud Functions için Blaze planı gerekir.

## Google Play abonelik kurulumu

1. Play Console'da StokPilot için `com.yesildas.stokpilot` package name ile uygulama oluşturun (ücretsiz uygulama).
2. **Monetize with Play → Products → Subscriptions** → `stokpilot_pro_monthly` adlı abonelik açın.
3. `monthly-50` gibi benzersiz base plan ID ve **Auto-renewing, 1 month** belirleyin. Türkiye fiyatını 50 TL olacak şekilde bölge fiyat panelinden kontrol edin ve base plan'ı **Activate** edin. Vergi/mağaza gösterimine göre gerçek fiyatı doğrulayın.
4. RevenueCat → Android app → Google Play service credentials / izinler, ürün import → Entitlement **`pro`** → Offering **`default`** → **Monthly** paketini ürüne bağlayın.
5. Internal testing track ve license testers ekleyin; Google Play test APK/AAB (Play üzerinden) ile sandbox ürünleri test edin.

## App Store abonelik kurulumu

1. Apple Developer Bundle ID `com.yesildas.stokpilot` açın; Sign in with Apple ve In-App Purchase yeteneklerini yapılandırın.
2. App Store Connect → My Apps → StokPilot → Monetization → **Subscriptions** → Subscription Group `StokPilot Pro` oluşturun.
3. Ürün ID `stokpilot_pro_monthly`, Type: **Auto-Renewable**, Duration **1 Month**, Türkiye storefront ve 50 TL veya Apple'ın izin verdiği **en yakın fiyat kademesini** seçin; yerelleştirme/ad/açıklama, review screenshot ve tax/banking Agreements ayarlarını tamamlayın.
4. RevenueCat → iOS app → App Store Connect In-App Purchase Key / App Store integration, ürün eşleştirme → entitlement `pro`, offering `default`, monthly package.
5. Sandbox tester/TestFlight ile satın alma, yenileme, iptal, restore ve iade akışını test edin. İlk auto-renewing aboneliği gerekli inceleme sürecinde uygulama sürümüyle birlikte sunun.

## RevenueCat + Firebase webhook

Firebase CLI: `firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET` komutuna kendi ürettiğiniz güçlü gizli değeri girin. RevenueCat Webhooks üzerinde endpoint olarak deploy edilen `revenueCatWebhook` HTTPS URL'sini ve header olarak `Authorization: Bearer <SECRET>` tanımlayın. **Secretları GitHub'a / Flutter kaynak koduna eklemeyin.**

```powershell
firebase deploy --only functions,firestore
flutter run --dart-define=RC_ANDROID_PUBLIC_KEY=goog_YOUR_PUBLIC_KEY
flutter build appbundle --release --dart-define=RC_ANDROID_PUBLIC_KEY=goog_YOUR_PUBLIC_KEY
```

iOS build yalnızca Mac/Xcode veya doğru yapılandırılmış Mac CI üzerinde: `flutter build ipa --release --dart-define=RC_IOS_PUBLIC_KEY=appl_YOUR_PUBLIC_KEY`.

## Yayın öncesi kritik eksikler

Bu depo **başlangıç uygulamasının geliştirilmiş kaynak kodudur**, kendiliğinden canlı ödeme veya mağaza yayımlaması yapmaz. Canlı Firebase deploy, mağaza ürünlerinin etkinleştirilmesi, RevenueCat API anahtarları, public gizlilik/KVKK ve şartlar URL'leri, ekran görüntüleri, dijital hizmet vergi/banka sözleşmeleri, Android imzalama, Apple signing, staging/test, kritik stok işlemleri güvenlik/emulator testleri, restore/refund/transfer ve abonelik senkronizasyonu ayrıca doğrulanmalıdır.

Özellikle ürün limiti yalnızca UID/işletme bazındadır. Bir kişi birden çok misafir hesap açarak kotayı tekrar elde edebilir; bu model global cihaz veya kişi başına 50 sınırı sağlamaz. İhtiyaç olursa App Check, abuse prevention ve hesap doğrulama tasarlanmalıdır. 
