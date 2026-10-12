# StokPilot — Premium responsive arayüz yenilemesi

Bu güncelleme **Firebase Spark**, 50 ücretsiz ürün sınırı, mağaza abonelik
bekletme güvenliği, Firestore işlemleri ve mevcut kullanıcı verilerini değiştirmez.

## Mobil / tablet / masaüstü

- 0–759 px: telefon alt gezinme çubuğu ve tüm modüllere açılan menü
- 760–1109 px: dar yan menü (simge + erişilebilir tooltip)
- 1110 px ve üstü: tam genişlikte premium yan menü
- En fazla 1240 px içerik; akıllı kartlar ve taşmayan metinler
- Giriş formları ve ürün düzenleme alanları dar ekranda alt alta yerleşir

## Kullanımı kolaylaştıran değişiklikler

- İşletme ana ekranı: hızlı ürün/satış/alış/cari kısayolları, canlı dört finansal gösterge
- Kritik stokları ayrı panelde gösterme, ürün listesine hızlı geçiş
- Ürün listesi: ad/barkod/SKU arama, kategori, kritik stok, tükenen ve pasif filtreleri
- Ürün sıralama: isim, stok, satış fiyatı, eklenme tarihi
- Mobilden barkod kopyalama, stok giriş-çıkış, ürün düzenleme menüsü
- Listeyi 30'ar kayıt artan sayfalama ile görüntüleme
- Cariler: müşteri/tedarikçi filtreleri, toplam borç/alacak özetleri
- Mobil cariler: ödeme ve hareket geçmişine kolay erişim
- Satış/alış: okunabilir sepet satırları, net tutar/KDV/toplam ayrımı
- Tutarlı renk paleti, kontrast, boş durum kartları ve işlem açıklamaları
- Misafir çıkışında veri kaybı uyarısı

## Test ve dağıtım

GitHub Actions, Flutter analizini ve widget testlerini çalıştırır. Canlı
Firebase projesine yalnızca uygulama kodu güncellendiği için yeniden
Firestore kuralı yüklemek gerekmez.

Windows:

```powershell
cd C:\Users\HGDGFJr\StokPilot-GitHub
git status --short
git pull --ff-only origin main
flutter pub get
flutter analyze
flutter test
flutter run
```

`git pull` yerel değişikliklerden dolayı durursa **git reset --hard** veya
**git clean -fd** çalıştırmayın. Önce değişikliklerin yedeğini alın.

> Aylık 50 TL abonelik canlı mağaza ürünleri ve güvenli Cloudflare/RevenueCat
> bağlantıları tamamlanmadan etkin değildir. Görsel yenileme ödeme açmaz.
