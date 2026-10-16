# StokPilot mağaza teslim durumu — 16 Ekim 2026

## Doğrulanan sürüm

- [1.0.0+12 GitHub çalıştırması](https://github.com/otsho675-afk/StokPilot/actions/runs/38924949447): Flutter analiz ve ekran testleri, imzalı Android AAB ile iOS IPA derlemeleri, Play dahili test yüklemesi ve App Store Connect IPA yüklemesi başarılı. AAB ve IPA bu çalıştırmanın indirilebilir paketleri arasında.
- Apple'ın yüklenen IPA'yı işlemesi, uygulama ve abonelik incelemesi ayrıca tamamlanmalıdır. Genel yayın henüz açık değil.
- Ekran testi 320, 360, 393 ve 430 piksel telefon genişlikleri ile 1024 piksel iPad görünümünü kontrol ediyor; rapor ekranı da bu boyutlarda denetlendi.

## Mağaza ve ödeme durumu

- Google Play `stokpilot_pro_monthly` / `monthly-50` ürünü Türkiye'de 50,00 TRY/ay fiyatla aktif; RevenueCat `pro` yetkisine ve Monthly paketine bağlı.
- Apple `stokpilot_pro_monthly` aboneliği 1 aylık ve Türkiye için 50,00 TRY olarak kaydedildi; abonelik incelemesi ve gerçek mağaza satın alma testi tamamlanmadı.
- `RC_VERIFIED_BACKEND_READY=false` korunuyor. Sandbox satın alma, geri yükleme, yenileme, süre bitimi ve Firebase Pro erişim güncellemesi uçtan uca doğrulanana kadar uygulama aylık ücret tahsil etmiyor.
- Google Play üretim erişimi için konsolun istediği en az 12 kayıtlı test kullanıcısı ve 14 kesintisiz günlük kapalı test henüz tamamlanmadı.

## Tasarım ve veri

- Satış/alış formu sadeleştirildi: ürün adı, SKU ve barkodla arama; müşteri/tedarikçiyi isim veya telefonla bulma; yazılan isim için yeni cari kartı açıp işlemde seçme; belge ve vergi ayrıntılarını isteğe bağlı açma; mobilde sepetten ödemeye geçiş.
- Ürün kartları ad, satış fiyatı ve stok durumuna odaklandı. Ürün listesi ile gelişmiş filtreler ayrıldı; satış ve ürün görselleri Android, iPhone ve iPad boyutlarında yenilendi.
- Raporlarda dönem satışları, alış ve stok, güncel cari durum ve para hareketleri ayrı gösteriliyor. Satışta alınan ilk ödeme ile sonradan yapılan cari tahsilat birbirine karıştırılmıyor.
- Sepet, satış öncesi stok yetersizliğini engeller; satış sonrası kritik stok ve işlem sırasında değişen fiyat için uyarı verir. Ürün formu tam ismin yazılması kısa süre durduktan sonra benzer kayıtları önerir; birebir mükerrer kaydı engellemeyi sürdürür.
- Genel arama ürün, barkod, SKU, müşteri, tedarikçi ve fiş kayıtlarını bulur. Ürün/firma kartı veya seçilen fiş açılabilir.
- Kritik stok ve fiyat güncelliği uyarıları ürün ekranında ve üst çubuktaki rozetli hatırlatıcı merkezinde gösteriliyor.
- Ücretsiz ürün kotası toplam 50 oluşturmadır. Ürün silmek kotayı geri kazandırmaz.

## Kalan yayın işleri

- Apple yüklenen derlemeyi işlemeli; App Store sürüm incelemesi ve abonelik incelemesi başlatılmalı.
- Google Play kapalı test kullanıcıları ve süre koşulu tamamlanmalı; ardından üretim erişimine başvurulmalı.
- Gerçek mağaza sandbox satın alımları ve sunucu doğrulaması geçmeden Pro ödeme anahtarı etkinleştirilmemeli.
