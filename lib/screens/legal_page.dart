import 'package:flutter/material.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.privacy});
  final bool privacy;
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(privacy ? 'Gizlilik bildirimi' : 'Kullanım koşulları')),
    body: SingleChildScrollView(padding: const EdgeInsets.all(22), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: SelectableText(
      privacy
        ? '''STOKPILOT GIZLILIK BILDIRIMI - TASLAK

Bu metin yayın öncesi gerçek işletmeci ve veri işleme süreçleriyle güncellenmelidir.

Toplanabilecek bilgiler: Hesap e-postası ve giriş bilgileri; işletmenin kaydettiği ürün, cari, alım, satım ve stok hareketleri; abonelik durumunu doğrulamak için Google Play / App Store ve RevenueCat olayları.

Amaç: Kimlik doğrulama, senkronizasyon, stok/cari yönetimi, abonelik erişimi, güvenlik, hata teşhisi.

Altyapı: Firebase Authentication, Cloud Firestore ve Cloud Functions. Mağaza içi ödemelerin doğrulaması için RevenueCat kullanılır. Kart bilgileri StokPilot içinde tutulmaz.

Saklama: Hesap var oldukça ilgili kayıtlar saklanabilir. Uygulamada hesap silme talep edildiğinde işletme verileri ve hesap kaldırılır. Yasal saklama yükümlülükleri ayrıca değerlendirilmelidir.

Haklar ve iletişim: Veri sorumlusu adı, iletişim e-postası, KVKK aydınlatma metni, veri aktarım şartları ve talep süreci yayın öncesinde eklenmelidir.'''
        : '''STOKPILOT KULLANIM KOŞULLARI - TASLAK

Bu metin uygulama yayınından önce işletmecinin hukuki bilgileriyle tamamlanmalıdır.

Hizmet: Stok ve cari takibi, işlem kaydı ve raporlama yazılımıdır. E-fatura veya mali müşavirlik hizmeti değildir. Raporlar resmî muhasebe ve KDV beyannamesi yerine geçmez.

Abonelik: Ücretsiz hesaplar (misafir, Google, Apple ve e-posta) en fazla 50 ürün ekleyebilir; diğer temel özellikler ücretsiz kullanılabilir. 50 üründen daha fazla kayıt oluşturmak için StokPilot Pro aylık aboneliği gerekir. Türkiye için hedef fiyat 50 TL/ay olup bağlayıcı tutar ödeme ekranında mağazanın gösterdiği fiyattır. Gerçek tutar, para birimi, yenileme ve deneme bilgisi satın almadan önce mağaza ödeme ekranında gösterilir. Abonelik mağaza hesabı üzerinden otomatik yenilenir; iptal mağazanın abonelik ayarlarından yapılabilir.

Hesap silme: Hesabı silmek mağaza aboneliğini kendiliğinden iptal etmez. Önce Apple veya Google aboneliklerinden iptal edilmelidir.

Verilerin doğruluğu: Kullanıcı ürün, fiyat, stok, KDV ve cari bilgilerinin doğruluğundan sorumludur.

Düzenleyici bilgiler: İşletmeci ünvanı, adres, iletişim, iadeler ve yürürlük tarihi yayın öncesi tamamlanmalıdır.''',
      style: const TextStyle(height: 1.55, fontSize: 15),
    )))),
  );
}
