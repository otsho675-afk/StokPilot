# StokPilot - Flutter + Firebase Spark

Responsive, çok platformlu stok ve cari yönetimi. **Firebase Blaze yükseltmesi gerekmez.** Android/iOS Flutter istemcisi Firestore transaction ve Firebase Authentication kullanır.

## Temel özellikler

- Misafir, Google, Apple (iOS/uygun platformlar) ve e-posta hesabı.
- Ürün, barkod, kategori, birim, alış/satış fiyatı, KDV oranı.
- Kritik stok takibi, manuel stok giriş/çıkış ve hareket geçmişi.
- Kullanıcının seçtiği kritik stok ve 30/45/60/90/180 günlük fiyat güncelleme uyarıları; aynı ürün adı, barkod veya SKU için kayıt öncesi uyarı.
- Telefon ve masaüstü üst çubuğunda stok/fiyat hatırlatıcı rozeti; uyarıdan ilgili ürün veya stok işlemine geçiş. Türkçe karakter farkları da mükerrer ürün eşleştirmesine dahildir.
- Tamamlanan alış/satış işlemlerinden sonra, uygun zamanda ve seyrek gösterilen yerel mağaza değerlendirme isteği.
- Çok kalemli alış/satış, stok güncellemeleri, cari borç-alacak, tahsilat ve ödeme.
- Responsive masaüstü/tablet/telefon ekranları, raporlar.
- Finans ve giderler: dönemlik tahsilat, tedarikçi ödemesi, işletme gideri ve para hareketi defteri.
- Ayrı müşteri ve tedarikçi ekranları, firma kartları, geçmiş borç/alacak ve belgeye bağlı ödemeler.
- Numaralı satış/alış fişleri; fatura veya proje bilgisi, nakit/kart/veresiye ve kalan tutar takibi.
- Telefon ve masaüstünde tek dokunuşla ürün, barkod, SKU, cari ve fiş arama; ürün ve firma kartına doğrudan geçiş.
- **50 ücretsiz ürün**: ürün sayacı Firestore transaction + kurallarla korunur. Ürün silmek kotayı geri kazandırmaz. Başka misafir UID'si açmak yeni ücretsiz kota sağlayabilir.
- **StokPilot Pro aylık 50 TL hedef fiyatı**: mağazaya ait ürünler RevenueCat ile bağlanır, Cloudflare Worker bağımsız ve doğrulamalı ödeme köprüsünü sunar. Ödeme kurulum ve Sandbox doğrulaması yapılmadan devre dışıdır.

## Kurulum

Tam Spark kurulum komutları ve açıklamalar: [SPARK_KURULUM.md](SPARK_KURULUM.md).

Windows PowerShell, proje klasöründe:

```powershell
cd C:\Users\HGDGFJr\StokPilot-GitHub
git pull origin main
flutter pub get
firebase login
firebase deploy --only firestore --project stokpilot-5bd2e
flutter run
```

**`firebase deploy --only functions` çalıştırmayın.** Firebase Cloud Functions Spark üzerinde dağıtılamaz. Eski `scripts/deploy_backend_windows.ps1` dosyası artık yalnızca Firestore dağıtır; Blaze istemez.

## Pro abonelik

Ücretsiz katmanlı Cloudflare Worker ve RevenueCat bağlantısı: [cloudflare-billing/README.md](cloudflare-billing/README.md).

RevenueCat Google Play doğrulaması, Cloudflare Worker ve Firebase yetki köprüsü kuruludur. Google Play abonelik planı Türkiye için vergi dahil 50 TL/ay fiyatla aktiftir; iOS RevenueCat bağlantısı ve gerçek mağaza satın alma testleri tamamlanmamıştır. Bu nedenle `RC_VERIFIED_BACKEND_READY=false` kalır ve uygulama henüz aylık ödeme almaz. Gerçek mağaza fiyatı açıldığında mağaza SDK'sından gelir.

`.github/workflows/store-release.yml` manuel Android/iOS seçimi veya `v*` etiketiyle imzalı Android AAB ve macOS üzerinde iOS IPA oluşturur. [1.0.0+10 otomasyonu](https://github.com/otsho675-afk/StokPilot/actions/runs/38783144014) Android paketini Play dahili teste yükledi; Play Console sürüm kodu 10'u etkin gösteriyor. Aynı çalıştırmada imzalı iOS IPA oluşturuldu ve App Store Connect yükleme adımı başarılı oldu. Bu, mağaza incelemesinin veya genel yayının tamamlandığı anlamına gelmez.

Güncel derleme, görsel yükleme ve yayın engelleri: [Mağaza teslim durumu](store_assets/RELEASE_STATUS.md).

## Güvenlik ve sınırlamalar

- `workspaces/{uid}` verilerini yalnızca Firebase Auth'ta o UID'ye sahip kullanıcı okur/değiştirir.
- Ürün sayaç artışı yeni ürün oluşturmayla aynı transaction'dadır; 51. ürüne güvenlik kuralları izin vermez. Silinen hesapların kota sıfırlama saldırısına karşı yalnızca **minimal teknik kota kaydı** tutulur.
- Müşteri kendine ait stok ve muhasebe verisini SDK üzerinden değiştirebilir; bu sistem değiştirilemez, resmî muhasebe/yasal defter değildir.
- Hesap silindiğinde detaylı ürün/cari/ödeme verileri temizlenir; kötüye kullanımı engelleyen UID ile ilişkili minimal kota bilgileri tutulur. Silme/recent sign-in ve hukuki saklama süreçleri mağaza yayını öncesinde gözden geçirilmelidir.
- Firebase Spark'ın Firestore günlük okuma/yazma ve depolama kotaları vardır; kotayı aşarsa hizmet durabilir.
- Gizlilik, kullanım koşulları ve hesap silme sayfaları Firebase Hosting'de yayımlanmıştır; mağaza incelemesi ve gerçek satın alma testi henüz sonuçlanmamıştır.

## Testler

GitHub Actions üç kontrol çalıştırır: Flutter analiz/test, Firebase Emulator ile 50 ürün güvenlik testi, Cloudflare ödeme olayı durum testleri. Bu testler başarıyla geçse de canlı Firebase/Auth/mağaza yapılandırması otomatik tamamlanmış sayılmaz.
