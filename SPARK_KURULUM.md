# StokPilot - Firebase Spark (ücretsiz) kurulum

Uygulama Firebase **Spark** planıyla çalışacak şekilde düzenlendi. Firebase Cloud Functions **kullanılmaz**. Misafir, Google veya Apple ile giriş için Firebase Authentication; ürün, stok, kategori, birim, KDV, cari, alış, satış ve rapor için Firestore kullanılır.

## Windows PowerShell - ilk kurulum

```powershell
cd C:\Users\HGDGFJr\StokPilot-GitHub
git pull origin main
flutter pub get
firebase login
firebase deploy --only firestore --project stokpilot-5bd2e
flutter run
```

**Cloud Functions dağıtmaya çalışmayın:** `firebase deploy --only functions` ve eski `scripts/deploy_backend_windows.ps1` komutları Spark sürümünde kullanılmaz. Giriş çalışmıyorsa Firebase Console -> Authentication -> Sign-in method bölümünde Anonymous, Google ve Apple (kurulumdan sonra) girişlerini etkinleştirin.

Firestore veri tabanının `stokpilot-5bd2e` projesinde oluşturulmuş ve uygulamanın Android `google-services.json` veya iOS `GoogleService-Info.plist` dosyasının aynı projeye ait olması gerekir. İlk kurulumda `flutterfire configure --project=stokpilot-5bd2e --platforms=android,ios --android-package-name=com.yesildas.stokpilot --ios-bundle-id=com.yesildas.stokpilot` kullanabilirsiniz.

## 50 ücretsiz ürün

Ürün oluştururken Flutter Firestore transaction kullanır: bir ürün belgesi oluşturur ve `workspaces/{uid}` altında `productCount` değerini artırıp `lastProductId` değerini yeni ürünün ID'sine ayarlar. Firestore kuralları **tek yazma işlemiyle yalnızca bir ürün için bu artışa izin verir.** 50 ürün limitine ulaşıldıktan sonra ücretli yetki belgesi yoksa 51. ürün engellenir. Kullanıcının ürün silmesi kotayı geri kazandırmaz. Aktif Pro kullanıcılarının kotası sınırsızdır.

Her cihazın aynı verileri okuması ve satışta stok miktarının eksiye düşmemesi için Firestore transaction'ları kullanılır. Sahip yalnızca kendi UID'sine ait işletme belgelerini okuyabilir ve yazabilir. Kullanıcının kendi stok/cari kayıtlarına SDK üzerinden doğrudan müdahale etmesi bu kişisel yönetim sürümünde mümkün olduğu için değiştirilemez **resmî muhasebe kayıt sistemi** olarak kullanılmamalıdır.

## Aylık 50 TL abonelik

Google Play ve App Store abonelik ürünlerini (hedef 50 TL/ay) RevenueCat ile eşleştirebilirsiniz. Ancak uygulama içinden satın alma yapıldığı bilgisini tek başına Pro erişimi olarak kabul etmek **güvensizdir**. Pro yetkisini yalnızca yetkili bir sunucunun, makbuz durumunu doğrulayıp Firestore `entitlements/current` belgesini güncellemesiyle veriyoruz. Firebase Spark bu sunucu kodunu Cloud Functions ile çalıştırmaya izin vermez.

Cloudflare Workers + RevenueCat abonelik köprüsünün kurulumu: [cloudflare-billing/README.md](cloudflare-billing/README.md). Bu test sürümünde `RC_VERIFIED_BACKEND_READY` varsayılan `false` olduğu için **gerçek ödeme butonu kapalıdır**. Sonraki aşamada bağımsız Cloudflare Workers veya diğer güvenilir bir sunucuda mağaza doğrulama entegrasyonu kurulup test edilmeden ödeme açılmamalıdır. Bu ayar tek başına güvenlik vermez; Firestore Pro kontrolü yalnızca `source=revenuecat`, `status=active` ve gelecekteki `expiresAt` özellikli sunucu yetkisine güvenir.

## Hesap silme

Spark sürümü hesap silme isteğinde ilgili kullanıcının Firestore koleksiyonlarını istemciden 100'lü gruplar halinde siler, işletme ana belgesindeki isim bilgisini anonimleştirir, tekrar kullanımını engelleyen minimal teknik kota kaydını korur ve sonra Firebase Auth hesabını kaldırır. Firebase, güvenlik nedeniyle hesabı silerken yakın zamanda tekrar giriş isteyebilir; işlem yarıda kesilirse tekrar denenmelidir. Abonelik mağaza hesabından ayrıca iptal edilir.

## Spark kotaları

Spark'ın ücretsiz okuma, yazma ve depolama limitleri vardır. Limit aşılırsa ilgili hizmet sonraki faturalandırma dönemine kadar durabilir. Bu model sıfır ücretle **sınırsız trafik** sağlamaz. Firestore ürün kotası da kullanıcı UID/işletme başına uygulanır; aynı kişinin farklı misafir hesap açmasını bütünüyle engellemez.
