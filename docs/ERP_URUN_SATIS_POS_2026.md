# StokPilot — ERP Ürün ve Satış Güncellemesi

## Ürün formu

- Otomatik barkod: 20 ile başlayan, EAN-13 kontrol basamağı doğru mağaza içi kod oluşturur. GS1 tarafından tahsis edilen küresel barkod değildir.
- Uygulama barkod tekrarını aynı işletmedeki mevcut ürünlere karşı kontrol eder. Eşzamanlı kayıt için sunucu seviyesinde kesin tekillik garantisi verilmez.
- KDV: %0, %1, %10, %20 ve tanımlı özel oranlar.
- Alış ve satış fiyatı KDV hariç girilir; KDV dahil fiyatlar anlık gösterilir. Net fiyatlar eski Firestore formatında saklanır.
- Animasyonlu tahmini kâr (maliyet üzerinden): (KDV hariç satış - KDV hariç alış) / KDV hariç alış * 100. Giderler hariçtir; muhasebe kârı veya brüt marj değildir.

## Satış / POS

- Barkod tam eşleşmesi stok kodu ve isim sonuçlarından önce gelir; Türkçe karakter ve birden çok kelime araması desteklenir.
- Ürün önerilerinde stok, barkod, fiyat görüntülenir.
- Nakit / Kart: tam tahsilat kaydı. Kart seçimi gerçek POS'tan para çekmez.
- Veresiye: müşteri/cari zorunlu; ilk tahsilat sıfır, cari alacak artar.
- Tedarikçi alışında mevcut kısmi ödeme davranışı değişmez.
- ERP İşlemleri ve Raporlar: ödeme yöntemi ve nakit/kart/veresiye satış hacimleri görünür. Veresiye ciro tahsilat değildir.

## Windows

~~~~powershell
cd C:\Users\HGDGFJr\StokPilot-GitHub
git status --short
git pull --ff-only origin main
flutter pub get
flutter analyze
flutter test
firebase deploy --only firestore --project stokpilot-5bd2e
flutter run
~~~~

YENİ Firestore kuralları (paymentMethod ve ödeme method alanları) yayımlanmadan yeni satışlar reddedilir. Blaze ve Cloud Functions gerekmez.

Yerel Android/iOS/Firebase kurulumlarını silmeyin. Misafir hesabı kullanıyorsanız uygulamayı cihazdan kaldırmayın.

Test: Ürün ekle -> otomatik barkod üret -> %20 KDV, alış 100, satış 150 -> KDV dahil alış 120, satış 180, yaklaşık %50 kâr. Satışta nakit, kart ve seçilmiş cariye veresiye ayrı ayrı test edin.

50 TL aylık Pro aboneliği, mağaza ödeme entegrasyonu ve bağımsız güvenli doğrulama tamamlanmadan canlı ödeme açmaz.
