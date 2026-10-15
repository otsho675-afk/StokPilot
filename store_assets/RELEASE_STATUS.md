# StokPilot mağaza teslim durumu — 15 Ekim 2026

## Tasarım ve doğrulama

- Flutter analyze sorunsuz; tam Flutter test paketi 48 testle geçti.
- Ortak tema, mobil gezinme, form eylemleri, ürün ve müşteri filtreleri, genel bakış ve Pro ekranı yenilendi.
- Gerçek uygulama bileşenleri, izole ve kurgusal mağaza kayıtlarıyla Android, iki iPhone boyutu ve iPad üzerinde ekran görüntüsü testinden geçirilir.
- `screenshots/redesign/` dosyaları bu testlerden üretilir; canlı müşteri bilgileri içermez.
- Ücretsiz kota toplam 50 ürün oluşturmadır. Ürün silmek kotayı geri kazandırmaz.

## Google Play

- `stokpilot_pro_monthly` / `monthly-50`: Türkiye'de vergi dahil **50,00 TRY / ay**, aktif.
- RevenueCat ürünü Published; `pro` yetkisine ve `default` offering içindeki Monthly paketine bağlı.
- Dört yeni Android ekran görüntüsü yüklendi ve Türkçe mağaza girişi kaydedildi. Kayıt incelemeye gönderilmeye hazır; kamuya yayınlandığı anlamına gelmez.
- 1.0.0+6 Android derlemesi ve dahili test yüklemesi: https://github.com/otsho675-afk/StokPilot/actions/runs/38714574013
- Üretime erişim için konsolun istediği en az 12 test kullanıcısıyla 14 kesintisiz günlük kapalı test henüz tamamlanmadı.

## Apple

- Developer Program License Agreement, hesapta 15 Ekim 2026 kabul tarihiyle doğrulandı.
- Paid Apps Agreement güncellemesi kullanıcı onayı ve cihaz doğrulamasıyla tamamlandı; 15 Ekim 2026 başlangıç tarihiyle Active durumu doğrulandı.
- 1.0.0+6 imzalı IPA aynı GitHub çalıştırmasında oluşturuldu. App Store Connect yükleme anahtarları eksik olduğundan derleme başarısı Apple'a yükleme anlamına gelmez.
- iPhone 1179×2556 ve 1290×2796, iPad 2048×2732 ekran görüntüleri hazır.
- Apple görsel yükleme denemesi hata verdi; kaydedilmiş iOS görsel yüklemesi henüz doğrulanmadı.
- RevenueCat iOS bağlantı formu hazır; Apple In-App Purchase `.p8` anahtarı, Key ID ve Issuer ID gerekiyor.

## Canlı servisler ve kalan işler

- Firebase CLI ile `stokpilot-5bd2e` projesi, Android/iOS uygulama kimlikleri ve `(default)` Standard Firestore veritabanı (`europe-west3`) doğrulandı. Firebase web konsolu aralıklı yükleme/izin hatası verdi.
- RevenueCat webhook test olayı ödeme sunucusundan HTTP 200 / `ignored` aldı. TEST olayının yok sayılması beklenir; bu test satın alma yetkisinin yazıldığını kanıtlamaz.
- Gerçek mağaza sandbox satın alma, Pro erişimi, geri yükleme, yenileme ve süre bitimi doğrulanmadı. Bu nedenle `RC_VERIFIED_BACKEND_READY=false` kalır.
- iOS anahtarlarını bağlama, gerçek satın alma testleri, Apple görsellerini kaydetme ve mağaza incelemeleri tamamlanmadan sürüm bitmiş/üretimde olarak değerlendirilmemelidir.

