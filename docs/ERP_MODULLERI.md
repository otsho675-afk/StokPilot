# StokPilot ERP İşlem Merkezi — 2026

Bu sürüm mevcut Firebase Spark projesini, uygulama kimliklerini, Firestore
koleksiyonlarını, kullanıcı verilerini ve 50 ücretsiz ürün sayacını korur.

## Yeni modüller

- **ERP İşlem Merkezi:** Satış ve alışları tek işlem defterinde görüntüleme,
  cari veya ürün adına göre arama, satın alma/satış filtreleri ve açılabilir
  işlem ayrıntısı (net, KDV, ödeme, açık tutar, satır kalemleri).
- **Stok hareketleri:** Mevcut `stockMoves` kayıtlarını ürün isimleriyle
  ilişkilendirip manuel giriş/çıkış, satış ve alış hareketlerini takip etme.
- **CSV kopyalama:** Filtrelenmiş kayıtları ve raporları noktalı virgülle
  ayrılmış, UTF-8 BOM'lu CSV olarak panoya kopyalama. Gerçek dosya indirme
  değildir. Kullanıcı elektronik tabloya yapıştırabilir veya bir metin dosyasına
  kaydedebilir. Girdi metninden formül çalıştırma girişimleri etkisizleştirilir.
- **Yönetim raporları:** Dönemlik satış cirosu, alış toplamı, KDV, işlem
  adedi, ilk ödeme, açık satış tutarı; günlük satış eğilimi, çok satılan
  ürünler ve kritik stok aksiyon listesi.
- **Responsive yapı:** Mobilde işlem kartları, geniş ekranda okunaklı
  işlem kayıtları; küçük ekranda yatay taşmayan rapor bileşenleri.

## Sınırlar ve doğruluk

- Bu sürüm **resmî muhasebe / e-Fatura / e-Arşiv / bordro sistemi değildir**.
  Fatura kesmez, e-defter üretmez, belge numarası veya vergisel mevzuata
  uygunluk iddiası taşımaz.
- Raporun dönemlik açık satış tutarı, **işlemin kaydı sırasında ödenmeyen**
  kısmıdır. Daha sonra cari ekrandan yapılan tahsilatları dönem cirosundan
  indirmez. Güncel bakiye için cariler özetine bakılmalıdır.
- Stok maliyet değeri güncel alış fiyatından hesaplanır; geçmişteki
  değişen maliyetlerin muhasebesi değildir.
- İşlem ve stok hareketi ekranları mevcut Firestore koleksiyonlarından
  okuma yapar. Yeni yazma yetkisi, Cloud Function veya Blaze gerektirmez.
- Ürün/işlem sayısı çok büyüdüğünde mevcut `watch()` tüm kayıtları çeker.
  Üretim ölçeğinde sunucu sorgusu, Firestore sayfalama ve arşivleme ayrıca
  tasarlanmalıdır. Arayüz ilk 60 kayıtla başlayıp 'Daha fazla göster' sunar;
  bu yalnızca görüntüleme sayfalamasıdır.
- Aylık ücretli Pro satın alımları, RevenueCat ve ayrı doğrulama bağlantısı
  tamamlanmadan **canlı değildir**.

## Test etme

```
cd C:\Users\HGDGFJr\StokPilot-GitHub
git status --short
git pull --ff-only origin main
flutter pub get
flutter analyze
flutter test
flutter run
```

GitHub Actions; Flutter widget/birim testlerini, Firestore Emulator
kural testlerini ve abonelik worker testlerini çalıştırır. Cihazdaki
performans ve kullanıcı akışları ayrıca test edilmelidir.