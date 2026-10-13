# StokPilot ERP finans modülü

Mevcut ürün, alış, satış, cari ve rapor akışlarına **Finans** ekranı eklendi. Hedef veritabanı `stokpilot-5bd2e` projesindeki Standard sürüm `(default)` Firestore veritabanıdır.

- Kira, faturalar, personel, ulaşım, pazarlama ve diğer giderler tutar, ödeme yöntemi ve notla kaydedilir.
- Tahsilatlar, tedarikçi ödemeleri ve giderler dönem filtresiyle tek hareket defterinde izlenir; filtrelenmiş hareketler CSV olarak panoya kopyalanır.
- Raporlar ekranında seçilen dönemin para hareketi özeti görünür.
- Giderler yalnızca hesabın sahibi tarafından okunup oluşturulabilir. Uygulamada düzenleme/silme işlemi yoktur; hesap silme akışının çalışması için sahibi Firestore üzerinden silebilir.
- Hesap silme akışı gider kayıtlarını da temizler.

**Hesaplama sınırı:** Net para hareketi kaydedilmiş tahsilatlardan tedarikçi ödemeleri ve giderlerin çıkarılmasıdır. Nakit, kart ve banka birlikte sayılır. Açılış bakiyesi, banka mutabakatı, maliyet muhasebesi, resmî fatura veya kâr hesabı değildir. Eski cari ödeme kayıtlarında yöntem bulunmayabilir.

**Dağıtım:** Yeni giderlerin canlı ortamda kaydedilebilmesi için güncel `firestore.rules` yayımlanmalıdır. Firebase Spark üzerinde çalışır; yeni Cloud Function gerektirmez.

**Gider veri modeli:** `workspaces/{uid}/expenses/{id}` altında `title` (1–150 karakter), `category` (tanımlı altı kategoriden biri), `method` (nakit/kart/banka), `amountMinor` (pozitif kuruş), `note` (en çok 500 karakter) ve sunucu zaman damgası `createdAt` saklanır. Uygulama tüm giderleri anlık dinler ve dönem filtresini istemcide uygular; büyük veri kümelerinde sunucu tarafı sayfalama gerekir.
