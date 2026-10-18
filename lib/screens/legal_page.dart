import 'package:flutter/material.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.privacy});
  final bool privacy;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(privacy ? 'Gizlilik bildirimi' : 'Kullanım koşulları'),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SelectableText(
            privacy ? _privacy : _terms,
            style: const TextStyle(height: 1.55, fontSize: 15),
          ),
        ),
      ),
    ),
  );
}

const _privacy = '''STOKPILOT GİZLİLİK BİLDİRİMİ
Son güncelleme: 18 Ekim 2026
İşletmeci: Hazim Yesildas
İletişim: otsho675@gmail.com
Tam metin: https://stokpilot-5bd2e.web.app/privacy.html

Hesap ve giriş bilgilerinizi, uygulamaya eklediğiniz ürün, stok, firma, müşteri, tedarikçi, alış, satış, fiş, proje, gider, borç ve ödeme kayıtlarını hizmeti sağlamak için işleriz. Firma kartına girilen ad, ilgili kişi, telefon, e-posta, adres, vergi numarası ve IBAN da saklanır. Bu kayıtlar Firebase Authentication ve Cloud Firestore ile saklanır. Cari işlemlerde nakit/kart seçimi yalnızca kayıt etiketidir; kart numarası uygulamaya girilmez.

Pro aboneliği açıldığında satın alma durumu Apple App Store veya Google Play ile Cloudflare üzerindeki doğrulama hizmetimiz aracılığıyla kontrol edilir. Abonelik kimliği ve bitiş tarihi erişimi yönetmek için saklanır. Kart bilgileri StokPilot'a aktarılmaz. Hesap silme işlemi işletme alt kayıtlarını ve giriş hesabını kaldırır. Ücretsiz ürün kotasının yeniden kullanılmasını engellemek için kimlik ve sayaçtan oluşan sınırlı teknik kayıt tutulur.

Veri erişimi, düzeltme ve silme talepleri için otsho675@gmail.com adresine yazabilirsiniz. Hesap silme adımları: https://stokpilot-5bd2e.web.app/delete-account.html''';

const _terms = '''STOKPILOT KULLANIM KOŞULLARI
Son güncelleme: 13 Ekim 2026
İşletmeci: Hazim Yesildas
İletişim: otsho675@gmail.com
Tam metin: https://stokpilot-5bd2e.web.app/terms.html

StokPilot ürün, stok, müşteri, tedarikçi, alış, satış, fiş ve işletme içi finans kayıtları için bir yazılımdır. Fişler resmî e-fatura, e-arşiv fatura veya muhasebe defteri değildir. Vergi ve kayıt doğruluğunu kullanıcı kontrol eder.

Ücretsiz hesap 50 ürün oluşturabilir. Daha fazla ürün için aylık StokPilot Pro aboneliği gerekir. Kesin fiyat ve yenileme koşulları satın alma öncesinde Apple App Store veya Google Play tarafından gösterilir. Abonelik mağaza hesabından iptal edilir; hesabı silmek aboneliği otomatik iptal etmez. Güvenli abonelik doğrulaması hazır olana kadar yeni ödeme başlatılmaz.

Gizlilik: https://stokpilot-5bd2e.web.app/privacy.html
Hesap silme: https://stokpilot-5bd2e.web.app/delete-account.html''';
