# StokPilot - Flutter + Firebase Spark

Responsive, çok platformlu stok ve cari yönetimi. **Firebase Blaze yükseltmesi gerekmez.** Android/iOS Flutter istemcisi Firestore transaction ve Firebase Authentication kullanır.

## Temel özellikler

- Misafir, Google, Apple (iOS/uygun platformlar) ve e-posta hesabı.
- Ürün, barkod, kategori, birim, alış/satış fiyatı, KDV oranı.
- Kritik stok takibi, manuel stok giriş/çıkış ve hareket geçmişi.
- Çok kalemli alış/satış, stok güncellemeleri, cari borç-alacak, tahsilat ve ödeme.
- Responsive masaüstü/tablet/telefon ekranları, raporlar.
- Finans ve giderler: dönemlik tahsilat, tedarikçi ödemesi, işletme gideri ve para hareketi defteri.
- Ayrı müşteri ve tedarikçi ekranları, firma kartları, geçmiş borç/alacak ve belgeye bağlı ödemeler.
- Numaralı satış/alış fişleri; fatura veya proje bilgisi, nakit/kart/veresiye ve kalan tutar takibi.
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

Bu hizmet kullanıcı hesabınızda henüz kurulmamıştır. Flutter istemcisi güvenilir ödeme doğrulaması olmadan abonelik açmayı reddeder. Google Play ve App Store'da ürünleri oluşturup test ettikten sonra `RC_VERIFIED_BACKEND_READY=true` bayrağı kullanılabilir. Gerçek mağaza fiyatını uygulama mağaza SDK'sından alır.

## Güvenlik ve sınırlamalar

- `workspaces/{uid}` verilerini yalnızca Firebase Auth'ta o UID'ye sahip kullanıcı okur/değiştirir.
- Ürün sayaç artışı yeni ürün oluşturmayla aynı transaction'dadır; 51. ürüne güvenlik kuralları izin vermez. Silinen hesapların kota sıfırlama saldırısına karşı yalnızca **minimal teknik kota kaydı** tutulur.
- Müşteri kendine ait stok ve muhasebe verisini SDK üzerinden değiştirebilir; bu sistem değiştirilemez, resmî muhasebe/yasal defter değildir.
- Hesap silindiğinde detaylı ürün/cari/ödeme verileri temizlenir; kötüye kullanımı engelleyen UID ile ilişkili minimal kota bilgileri tutulur. Silme/recent sign-in ve hukuki saklama süreçleri mağaza yayını öncesinde gözden geçirilmelidir.
- Firebase Spark'ın Firestore günlük okuma/yazma ve depolama kotaları vardır; kotayı aşarsa hizmet durabilir.
- Firebase gizlilik/KVKK metinleri ve kullanım koşulları henüz yayına çıkmadan özelleştirilmelidir.

## Testler

GitHub Actions üç kontrol çalıştırır: Flutter analiz/test, Firebase Emulator ile 50 ürün güvenlik testi, Cloudflare ödeme olayı durum testleri. Bu testler başarıyla geçse de canlı Firebase/Auth/mağaza yapılandırması otomatik tamamlanmış sayılmaz.
