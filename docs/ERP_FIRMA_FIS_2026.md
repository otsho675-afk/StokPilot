# Firma kartları ve fiş akışları

## Ekranlar

- **Müşteri carileri** ve **Tedarikçiler** ayrı menülerdir. Eski `contacts` verileri taşınmaz; `both` türündeki eski firmalar iki listede de görünür.
- Firma kartında ilgili kişi, telefon, e-posta, vergi numarası/dairesi, IBAN, adres, güncel bakiye ve işlem geçmişi görünür.
- Tedarikçiye geçmiş/açılış borcu; müşteriye geçmiş alacak kaydedilebilir. Kayıt tarihi geçmişten seçilir, isteğe bağlı vade ve gecikme görünümü vardır. Kayıt türü açılış bakiyesi, mevcut fatura veya projedir. İşlem bakiyeyi atomik olarak günceller; stok ya da kasa hareketi üretmez.
- Geçmiş borç/alacak kaydının kalanına nakit veya kart ödemesi bağlanabilir. Belgenin kalanını aşan ödeme reddedilir. Genel cari ödemeleri de firma kartından yapılabilir.
- Satış ve alış işlemleri otomatik benzersiz fiş numarası, firma adı, kalemler, KDV, genel toplam, ilk ödeme, kalan, belge/proje bilgileriyle saklanır. Fiş metni kopyalanabilir.

## Önemli sınırlar

- **Fatura kaydı**, eldeki bir faturanın numarasını ve ilişkili işlemi saklar. Resmî e-Fatura veya e-Arşiv belgesi düzenlemez.
- Nakit/kart seçimi ödeme yönteminin kaydıdır; karttan tahsilat yapmaz.
- Eski `both` firma türünde tek bir net cari bakiye vardır. Tamamen ayrı müşteri ve tedarikçi bakiyeleri gereken firmalar iki ayrı kart olarak açılmalıdır.
- Belgeye bağlanmadan kaydedilen genel ödeme, firmanın toplam bakiyesini değiştirir; belirli bir geçmiş belgenin kalanını değiştirmez.
- Yeni fiş numarası Firestore belge kimliğinden türetilir; benzersizdir fakat sıralı değildir.
- Yeni koleksiyon `workspaces/{uid}/accountEntries`; eski kayıtlar olduğu gibi kalır. `firestore.rules` canlı projeye yayımlanmadan yeni formlar izin hatası alır.
