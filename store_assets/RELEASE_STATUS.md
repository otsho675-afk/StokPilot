# StokPilot mağaza teslim durumu — 15 Ekim 2026

## Doğrulanan sürüm

- [1.0.0+11 GitHub çalıştırması](https://github.com/otsho675-afk/StokPilot/actions/runs/38785346194): Flutter analiz ve ekran görüntüsü testleri, imzalı Android AAB derlemesi, Play dahili test yüklemesi ve imzalı iOS IPA derlemesi başarılı.
- Apple IPA, aynı çalıştırmada App Store Connect'e otomatik yüklendi. Apple işleme ve uygulama incelemesi ayrıca tamamlanmalıdır.
- Play Console, sürüm kodu 11'i dahili test kullanıcıları için etkin gösteriyor. Genel yayın henüz açık değil.
- Ekran görüntüsü testi 320, 360, 393 ve 430 piksel telefon genişlikleri ile 1024 piksel iPad görünümünü kontrol ediyor.

## Mağaza ve ödeme durumu

- Google Play `stokpilot_pro_monthly` / `monthly-50` ürünü Türkiye'de 50,00 TRY/ay fiyatla aktif; RevenueCat `pro` yetkisine ve Monthly paketine bağlı.
- Apple `stokpilot_pro_monthly` aboneliği 1 aylık ve Türkiye için 50,00 TRY olarak kaydedildi; abonelik incelemesi ve gerçek mağaza satın alma testi tamamlanmadı.
- `RC_VERIFIED_BACKEND_READY=false` korunuyor. Sandbox satın alma, geri yükleme, yenileme, süre bitimi ve Firebase Pro erişim güncellemesi uçtan uca doğrulanana kadar uygulama aylık ücret tahsil etmiyor.
- Google Play üretim erişimi için konsolun istediği en az 12 kayıtlı test kullanıcısı ve 14 kesintisiz günlük kapalı test henüz tamamlanmadı.

## Tasarım ve veri

- Mobil gezinme, ürün ve müşteri ekranları, formlar, raporlar, özet ve Pro ekranı yenilendi. Android, iPhone ve iPad mağaza görselleri gerçek uygulama bileşenleri ve kurgusal verilerle üretildi.
- Genel arama ürün, barkod, SKU, müşteri, tedarikçi ve fiş kayıtlarını bulur. Ürün/firma kartı veya seçilen fiş açılabilir.
- Kritik stok ve fiyat güncelliği uyarıları ürün ekranında ve üst çubuktaki rozetli hatırlatıcı merkezinde gösteriliyor.
- Ücretsiz ürün kotası toplam 50 oluşturmadır. Ürün silmek kotayı geri kazandırmaz.

## Kalan yayın işleri

- Apple yüklenen derlemeyi işlemeli; App Store sürüm incelemesi ve abonelik incelemesi başlatılmalı.
- Google Play kapalı test kullanıcıları ve süre koşulu tamamlanmalı; ardından üretim erişimine başvurulmalı.
- Gerçek mağaza sandbox satın alımları ve sunucu doğrulaması geçmeden Pro ödeme anahtarı etkinleştirilmemeli.
